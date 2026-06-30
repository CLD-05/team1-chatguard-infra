# envs/prod/platform-addons/namespaces.tf
# chatguard 앱 네임스페이스 — ArgoCD(team1-prod-chatguard)가 이 ns로 앱을 동기화한다.
# 다른 ns(argocd·keda)는 각 Helm release의 create_namespace=true로 생기지만,
# chatguard·monitoring은 Helm 주인이 없거나(앱 ns) Helm보다 먼저 리소스를 넣어야 해서
# 독립 kubernetes_namespace로 만든다(§4: Namespace = Terraform 소유). dev와 글자 단위 동일(별도 클러스터라 prefix 없음, A-5).
resource "kubernetes_namespace" "chatguard" {
  metadata {
    name = "chatguard"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "Team"                         = "team1"
    }
  }
}

# monitoring ns — kube-prometheus-stack(Grafana/Prometheus)이 사는 ns.
# 원래 prometheus_stack의 create_namespace=true로 생겼으나, H1: Grafana admin existingSecret
# (grafana-admin-credentials)을 helm_release보다 먼저 이 ns에 만들어야 해 TF 소유로 승격
# (chicken-egg 해소 순서: ns → secret → helm_release). main.tf에서 prometheus_stack은 create_namespace=false로 전환.
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "Team"                         = "team1"
    }
  }
}
