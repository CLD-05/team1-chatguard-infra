# envs/dev/platform-addons/namespaces.tf
# chatguard 앱 네임스페이스 — ArgoCD(team1-dev-chatguard)가 이 ns로 앱을 동기화한다.
# 다른 ns(argocd·keda·monitoring·external-secrets)는 각 Helm release의
# create_namespace=true로 생기지만, chatguard는 Helm 주인이 없는 "앱" ns라
# 독립 kubernetes_namespace로 만든다(§4: Namespace = Terraform 소유).
#
# provider 의존: platform-addons 루트의 kubernetes provider(remote_state.infra의
# EKS endpoint/CA 참조)를 사용 — kubernetes_secret.argocd_cluster_registration과
# 동일 provider·동일 타이밍이라 별도 depends_on 불필요(EKS는 1층 infra apply로 선존재).
# ArgoCD Application은 Terraform이 아니라 config 레포에서 적용되므로 Terraform
# 의존 그래프 밖 — ns가 platform-addons apply로 먼저 존재하면 다음 sync가 성공한다.
resource "kubernetes_namespace" "chatguard" {
  metadata {
    name = "chatguard"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "Team"                         = "team1"
    }
  }
}
