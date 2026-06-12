# envs/prod/platform-addons/main.tf

locals {
  secret_name = "${var.team}-${var.env}-grafana-credentials"
}

# ==============================================================================
# 🔐 동적 조립된 이름으로 AWS Secrets Manager 금고 실시간 낚아채기
# ==============================================================================
data "aws_secretsmanager_secret" "grafana_secret" {
  name = local.secret_name
}

data "aws_secretsmanager_secret_version" "grafana_secret_val" {
  secret_id = data.aws_secretsmanager_secret.grafana_secret.id
}

locals {
  grafana_password = sensitive(jsondecode(data.aws_secretsmanager_secret_version.grafana_secret_val.secret_string)["password"])
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
        }
      }
    })
  ]
}

# ------------------------------------------------------------------------------
# 📊 2. Prometheus & Grafana 모니터링 스택 주입 
# ------------------------------------------------------------------------------
resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
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
