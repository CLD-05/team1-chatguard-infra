# envs/prod/platform-addons/namespaces.tf
# chatguard 앱 네임스페이스 — ArgoCD(team1-prod-chatguard)가 이 ns로 앱을 동기화한다.
# 다른 ns(argocd·keda·monitoring)는 각 Helm release의 create_namespace=true로
# 생기지만, chatguard는 Helm 주인이 없는 "앱" ns라 독립 kubernetes_namespace로
# 만든다(§4: Namespace = Terraform 소유). dev와 글자 단위 동일(별도 클러스터라 prefix 없음, A-5).
resource "kubernetes_namespace" "chatguard" {
  metadata {
    name = "chatguard"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "Team"                         = "team1"
    }
  }
}
