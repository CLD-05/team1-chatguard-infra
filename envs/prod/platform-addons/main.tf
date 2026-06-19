# envs/prod/platform-addons/main.tf

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
        }
      }
    })
  ]
}

# AWS에서 기존 EKS 클러스터 정보를 읽어오는 센서 선언
data "aws_eks_cluster" "this" {
  name = "team1-${var.env}-cluster"
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
        # 필요시 테라폼 배포에 사용되는 마스터/어드민 Role ARN을 지정하거나 생략 가능
        # roleARN    = var.argocd_target_role_arn 
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
