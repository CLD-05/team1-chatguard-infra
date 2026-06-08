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
resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      grafana = {
        enabled       = true
        adminPassword = "admin" # 초기 대시보드 로그인 비밀번호
        persistence = {
          enabled = true
          size    = "10Gi"
        }
      }
      prometheus = {
        prometheusSpec = {
          retention = "15d" # 모니터링 메트릭 보관 주기
        }
      }
    })
  ]
}
