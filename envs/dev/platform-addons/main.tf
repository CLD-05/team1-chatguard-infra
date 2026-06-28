# envs/dev/platform-addons/main.tf

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "this" {
  name = "team1-${var.env}-cluster"
}

# ==============================================================================
# 🔐 AWS Secrets Manager에서 실시간으로 비밀번호 금고 낚아채기
# ==============================================================================
data "aws_secretsmanager_secret" "grafana_secret" {
  name = "team1-dev-grafana-credentials" # 1층 infra 레이어에서 생성했던 금고 명칭
}

data "aws_secretsmanager_secret_version" "grafana_secret_val" {
  secret_id = data.aws_secretsmanager_secret.grafana_secret.id
}

locals {
  grafana_password = sensitive(jsondecode(data.aws_secretsmanager_secret_version.grafana_secret_val.secret_string)["password"])
}

# ------------------------------------------------------------------------------
# 🚀 1. ArgoCD GitOps 엔진 주입 
# ------------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.3.1"
  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      server = {
        service = {
          type = "LoadBalancer"
          # D49 안전망: LBC가 만든 ArgoCD NLB에 표준 태그를 자동 부착한다.
          # 미부착 시 destroy 중단 때 Team 태그 없는 orphan NLB/SG가
          # DenyOtherTeamResources-team1 정책에 막힌다(2026-06-23 사고).
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = "Team=team1,Environment=dev,Project=chatguard,Owner=infra-lead"
          }
        }
      }
    })
  ]

  # B-5: LBC(webhook) Ready 이후에 argocd LoadBalancer Service를 생성 → 첫 apply 시 LBC 웹훅 레이스 제거.
  depends_on = [helm_release.lbc]
}

# =========================================================================
# EKS 클러스터 주소 및 인증서를 ArgoCD에 자동 매핑 
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
  depends_on = [
    helm_release.argocd
  ]
}

# ------------------------------------------------------------------------------
# 📊 2. Prometheus & Grafana 모니터링 스택 주입 
# ------------------------------------------------------------------------------
# envs/dev/platform-addons/main.tf 내부 프로메테우스 설정 부분

resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "69.8.2"
  namespace  = "monitoring"

  create_namespace = true

  values = [
    yamlencode({
      grafana = {
        enabled       = true
        adminPassword = local.grafana_password
      }
    })
  ]
}

# ==============================================================================
# 3. External Secrets Operator (ESO) — IRSA role · Helm 설치는 platform-addons/addons.tf로 이관(화해 B).
#    OIDC provider를 하드코딩 문자열이 아니라 infra의 aws_iam_openid_connect_provider.eks 리소스 참조
#    (remote_state output)로 연결하고, Secrets Manager 정책을 team1-${env}-* 로 최소권한화하기 위함.
# ==============================================================================

# ==============================================================================
# 📈 4. Prometheus Adapter 주입 (Custom Metrics API 엔드포인트 활성화)
# ==============================================================================
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
