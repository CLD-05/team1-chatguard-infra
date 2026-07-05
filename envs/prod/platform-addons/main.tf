# envs/prod/platform-addons/main.tf

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "this" {
  name = "team1-${var.env}-cluster"
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
          # D49 안전망(사전 배치): 현재 prod ArgoCD는 ClusterIP라 NLB가 없어 이 태그는
          # 무동작이다. 추후 LoadBalancer로 노출 전환 시 곧바로 Team 표준 태그가 박혀
          # orphan(2026-06-23 사고)을 예방하도록 미리 둔다.
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = "Team=team1,Environment=prod,Project=chatguard,Owner=infra-lead"
          }
        }
      }
    })
  ]

  # webhook race 방지: LBC의 service mutating webhook(failurePolicy=Fail)은 ClusterIP CREATE도 가로챔.
  # prod argocd는 ClusterIP라 자기 NLB는 없지만, LBC 미준비 시 "no endpoints available for
  # aws-load-balancer-webhook-service"로 실패 → LBC Ready 후 생성. dev argocd(B-5)와 parity.
  depends_on = [helm_release.lbc]
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
        roleARN     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/team1-${var.env}-eks-admin-role"
      }
    })
  }
  depends_on = [
    helm_release.argocd
  ]
}

# ------------------------------------------------------------------------------
# 🔐 Grafana 어드민 자격증명 Secret — 아래 kube-prometheus-stack의 grafana.admin.existingSecret이 참조.
#   차트(grafana 8.10.x)는 이 Secret에서 admin-user·admin-password 키를 GF_SECURITY_ADMIN_USER/PASSWORD로
#   읽는다(values.yaml admin.userKey/passwordKey 기본값). helm_release보다 먼저 monitoring ns에 존재해야
#   Grafana 파드가 기동(없으면 CreateContainerConfigError). 값(admin-password)은 코드/git 미커밋 —
#   apply 시 var.grafana_admin_password(TF_VAR 또는 gitignore된 terraform.tfvars)로 주입. dev grafana·jwt
#   수동주입과 동일 관례(CLAUDE §5: 시크릿 원문 코드·git 금지).
# ------------------------------------------------------------------------------
resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin-credentials"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  type = "Opaque"

  data = {
    "admin-user"     = "admin"
    "admin-password" = var.grafana_admin_password
  }
}

# ------------------------------------------------------------------------------
# 🔔 Alertmanager Slack Webhook 주입선 — Secrets Manager 금고(team1-prod-alertmanager-slack-webhook,
#   envs/prod/infra/secrets.tf)를 기존 ESO(ClusterSecretStore team1-prod-aws-secret-store, config 레포 정의)로
#   monitoring ns의 k8s Secret에 동기화. 아래 prometheus_stack의 alertmanagerSpec.secrets가 이 Secret을
#   파드에 마운트해 slack_api_url_file로 참조 — Webhook 원문은 git·state 어디에도 없음(CLAUDE §5).
#   ExternalSecret을 여기(platform-addons)에 두는 근거: monitoring ns·grafana-admin secret 등 모니터링
#   스택 부속은 platform-addons TF 소유이고, infra-secure-check P2도 "ESO는 이미 레포 책임 범위"로
#   인프라측 ESO 주입을 권고. (context CLAUDE §4의 ExternalSecret=config 소유는 앱 도메인(chatguard ns) 맥락)
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "alertmanager_slack_webhook" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "alertmanager-slack-webhook"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }
    spec = {
      refreshInterval = "1h" # config 레포 ExternalSecret 관례와 동일
      secretStoreRef = {
        name = "team1-prod-aws-secret-store" # config overlays/prod/clustersecretstore.yaml(namePrefix 적용명)과 정합
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "alertmanager-slack-webhook"
        creationPolicy = "Owner"
      }
      data = [{
        secretKey = "slack_webhook_url"
        remoteRef = {
          key = "team1-prod-alertmanager-slack-webhook" # property 없음 = SecretString 원문(raw URL) 전체
        }
      }]
    }
  }

  # ESO CRD·컨트롤러 선행(installCRDs=true) — 없으면 kind 미인식으로 생성 실패
  depends_on = [helm_release.external_secrets]
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
  create_namespace = false # monitoring ns는 TF 소유로 승격(namespaces.tf) — grafana admin secret을 helm보다 먼저 이 ns에 생성하기 위함

  values = [
    yamlencode({
      grafana = {
        enabled = true
        admin = {
          # adminPasswordKey(차트에 없는 무효 키)는 제거. 차트 정식 필드는 userKey/passwordKey이고
          # 기본값이 admin-user·admin-password — kubernetes_secret.grafana_admin이 그 두 키를 그대로
          # 공급하므로 existingSecret만 지정하면 정합(커스텀 키 불필요).
          existingSecret = "grafana-admin-credentials"
        }
        # D55: 사이드카가 chatguard ns의 대시보드 ConfigMap(config PR #46)을 인식하도록.
        # 기본값(null)은 릴리스 ns(monitoring)만 감시 → chatguard ns CM 미인식.
        sidecar = {
          dashboards = {
            searchNamespace = "ALL"
          }
        }
      }
      # §0-3 진단 후속: PrometheusRule 3종은 발화하나(E2 실측) alertmanager 설정 블록 부재로
      # 차트 기본 null receiver가 흡수 → Slack 경로 신설(DESIGN D6/B-4). severity 기반 단일 분기만(과설계 금지).
      alertmanager = {
        config = {
          global = {
            # Webhook은 값이 아니라 파일 경로만 — alertmanagerSpec.secrets 마운트 규약:
            # /etc/alertmanager/secrets/<Secret명>/<key> (위 kubernetes_manifest가 동기화)
            slack_api_url_file = "/etc/alertmanager/secrets/alertmanager-slack-webhook/slack_webhook_url"
          }
          route = {
            # 차트 기본값을 그대로 명시 — 아래 routes/receivers "리스트"는 helm 머지에서 기본을
            # 통째 대체하므로, 기본 라우트(Watchdog→null)와 null receiver를 반드시 재포함해야 함.
            group_by        = ["namespace"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "12h"
            receiver        = "null"
            routes = [
              # 차트 기본 복원: 항상 발화하는 Watchdog(heartbeat)이 Slack으로 새지 않게
              {
                receiver = "null"
                matchers = ["alertname = \"Watchdog\""]
              },
              # 현행 룰 3종 전부 도달: ModerationLatencyHigh·ModerationQueueBacklog(warning),
              # ModerationWorkerDown(critical) — config 레포 PrometheusRule의 severity 라벨 기준
              {
                receiver = "slack-chatguard"
                matchers = ["severity =~ \"warning|critical\""]
              }
            ]
          }
          receivers = [
            { name = "null" }, # root receiver 참조 대상 — 리스트 통째 대체라 재포함
            {
              name = "slack-chatguard"
              slack_configs = [{
                send_resolved = true
              }]
            }
          ]
        }
        alertmanagerSpec = {
          # ExternalSecret이 동기화한 k8s Secret을 Alertmanager 파드에 마운트
          secrets = ["alertmanager-slack-webhook"]
        }
      }
    })
  ]

  # grafana secret 선존재(없으면 grafana 파드 CreateContainerConfigError) + LBC webhook Ready
  # (prometheus_stack이 만드는 다수 Service CREATE가 LBC mutating webhook, failurePolicy=Fail에 걸림)
  # + alertmanager가 마운트할 webhook Secret 동기화 선행(ExternalSecret).
  depends_on = [kubernetes_secret.grafana_admin, helm_release.lbc, kubernetes_manifest.alertmanager_slack_webhook]
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

  # webhook race 방지: keda(metrics-apiserver·admission-webhook) Service CREATE가 LBC mutating
  # webhook(failurePolicy=Fail)에 걸림 → LBC Ready 후 생성.
  depends_on = [helm_release.lbc]
}

# (제거됨) 📈 Prometheus Adapter — chat-server 스케일러 KEDA 일원화(config #58)로
# 유일 소비자였던 커스텀 HPA가 소멸 → adapter 제거. dev main.tf와 대칭.
