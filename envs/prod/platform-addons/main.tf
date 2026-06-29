# envs/prod/platform-addons/main.tf

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "this" {
  name = "team1-${var.env}-cluster"
}

# ------------------------------------------------------------------------------
# 🚀 1. ArgoCD GitOps 엔진 주입 (보안 하드닝 및 버전 변수화)
# ------------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
          # D49 안전망(사전 배치): 현재 prod ArgoCD는 ClusterIP라 NLB가 없어 이 태그는
          # 무동작이다. 추후 LoadBalancer로 노출 전환 시 곧바로 Team 표준 태그가 박혀
          # orphan(2026-06-23 사고)을 예방하도록 미리 둔다.
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = "Team=team1,Environment=prod,Project=chatguard,Owner=infra-lead"
          }
        }
      }
    })
  ]
}

# =========================================================================
# EKS 클러스터 주소를 ArgoCD에 자동 매핑 (platform-addons 소관)
# =========================================================================
resource "kubernetes_secret" "argocd_cluster_registration" {
  metadata {
    name      = "${var.env}-eks-cluster-secret"
    namespace = "argocd"

    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  type = "Opaque"

  data = {
    server = data.aws_eks_cluster.this.endpoint
    name   = data.aws_eks_cluster.this.name

    config = jsonencode({
      tlsClientConfig = {
        insecure = false
        caData   = data.aws_eks_cluster.this.certificate_authority[0].data
      }
      awsAuthConfig = {
        clusterName = data.aws_eks_cluster.this.name
        roleARN     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/team1-${var.env}-eks-admin-role"
      }
    })
  }
}

# ------------------------------------------------------------------------------
# 📊 2. Prometheus & Grafana 모니터링 스택 주입 
# ------------------------------------------------------------------------------
resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_stack_version
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      grafana = {
        enabled = true
        admin = {
          existingSecret   = "grafana-admin-credentials"
          adminPasswordKey = "password"
        }
        # D55: 사이드카가 chatguard ns의 대시보드 ConfigMap(config PR #46)을 인식하도록.
        # 기본값(null)은 릴리스 ns(monitoring)만 감시 → chatguard ns CM 미인식.
        sidecar = {
          dashboards = {
            searchNamespace = "ALL"
          }
        }
      }
    })
  ]
}

# ------------------------------------------------------------------------------
# 🎛️ 3. KEDA 코어 엔진 주입 (Prod 환경 필수 추가 - 명세서 D12, D13 준수)
# ------------------------------------------------------------------------------
resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.keda_chart_version
  namespace        = "keda"
  create_namespace = true

  values = [
    yamlencode({
      operator = {
        scaleDownDelay = "300"
      }
    })
  ]
}

# ------------------------------------------------------------------------------
# 📈 4. Prometheus Adapter — Custom Metrics API(ws_active_connections HPA 메트릭). dev main.tf 복제.
# ------------------------------------------------------------------------------
resource "helm_release" "prometheus_adapter" {
  name             = "prometheus-adapter"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-adapter"
  version          = "4.11.0"
  namespace        = "monitoring"
  create_namespace = false

  values = [
    yamlencode({
      prometheus = {
        url  = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local"
        port = 9090
      }

      rules = {
        default = false

        custom = [
          {
            seriesQuery = "ws_active_connections{namespace!=\"\",pod!=\"\"}"
            resources = {
              template = "<<.Resource>>"
            }
            name = {
              matches = "^(.*)$"
              as      = "ws_active_connections_per_pod" # HPA 서류에서 불러올 최종 이름
            }
            metricsQuery = "sum(ws_active_connections{<<.LabelMatchers>>}) by (<<.GroupBy>>)"
          }
        ]
      }
    })
  ]

  depends_on = [
    helm_release.prometheus_stack
  ]
}
