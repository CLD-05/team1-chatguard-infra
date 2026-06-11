# envs/dev/platform-addons/main.tf

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
        }
      }
    })
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
