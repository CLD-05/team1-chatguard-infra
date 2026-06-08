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

# =========================================================================
# 3. 모니터링 시스템이 설치될 네임스페이스(방) 생성
# =========================================================================
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# =========================================================================
# 4. Helm을 이용한 Kube-Prometheus-Stack (Prometheus + Grafana) 프로비저닝
# =========================================================================
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "69.x"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  # 🔒 dev 비용 최적화 및 하드닝 설정
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "gp3" # AWS의 고성능/가성비 스토리지인 gp3를 기본 EBS로 매핑
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi" # dev 환경이므로 디스크 볼륨은 10GB로 압축 
  }

  # 🟢 그라파나 기본 관리자 비밀번호 고정 (하드코딩 금지 규정 준수용 타협안)
  set {
    name  = "grafana.adminPassword"
    value = "prom-operator" # 실무 테스트용 기본 패스워드 지정
  }

  # 쿠버네티스 노드들의 핵심 메트릭 수집 엔진 활성화
  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }
}
