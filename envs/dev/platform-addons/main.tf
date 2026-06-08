# =========================================================================
# 1. ArgoCD가 설치될 네임스페이스(방) 생성
# =========================================================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# =========================================================================
# 2. Helm을 이용한 ArgoCD 자동 프로비저닝
# =========================================================================
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.3.1" # 유효한 고정 마이너 버전 명시
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  set {
    name  = "server.metrics.enabled"
    value = "true"
  }
}
