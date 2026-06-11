# envs/dev/platform-addons/main.tf

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
        adminPassword = data.terraform_remote_state.infra.outputs.grafana_admin_password
      }
    })
  ]
}
