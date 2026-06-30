# envs/prod/platform-addons/addons.tf
# Phase 0 플랫폼 애드온(prod) — dev/platform-addons/addons.tf 복제.
# DESIGN A-1: Helm 설치(ESO·LBC·redis_exporter)는 Terraform 소유. ScaledObject/ServiceMonitor 등은 GitOps(config).
# ★ keda는 prod main.tf에 이미 존재(scaleDownDelay=300) → 여기서 재생성하지 않음(이름 충돌 방지).
#
# 의존(providers.tf/main.tf에 이미 선언된 것 재사용):
#   - data.terraform_remote_state.infra → oidc_provider_arn·oidc_provider_url·vpc_id·redis_endpoint·redis_port
#   - data.aws_eks_cluster.this         → 클러스터 이름 (main.tf 정의)
#   - data.aws_caller_identity.current  → account id (main.tf 정의)

locals {
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.infra.outputs.oidc_provider_url # https:// 제거된 형태
  vpc_id            = data.terraform_remote_state.infra.outputs.vpc_id
  redis_endpoint    = data.terraform_remote_state.infra.outputs.redis_endpoint
  redis_port        = data.terraform_remote_state.infra.outputs.redis_port
  cluster_name      = data.aws_eks_cluster.this.name
}

# =============================================================================
# 1. AWS Load Balancer Controller(LBC) — Ingress(class=alb)가 ALB를 실제로 프로비저닝하게 함(D47).
#    IRSA: kube-system/aws-load-balancer-controller SA ↔ team1-${env}-lbc-role.
# =============================================================================
data "aws_iam_policy_document" "lbc_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name                 = "team1-${var.env}-lbc-role"
  permissions_boundary = var.permissions_boundary_arn # CLAUDE.md §1-7: 없으면 apply 거부
  assume_role_policy   = data.aws_iam_policy_document.lbc_trust.json
}

resource "aws_iam_policy" "lbc" {
  name   = "team1-${var.env}-lbc-policy"
  policy = file("${path.module}/iam/lbc-policy.json") # 공식 정책(kubernetes-sigs aws-lbc v2.7.2)
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_lbc_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = local.cluster_name
    region      = "ap-northeast-2"
    vpcId       = local.vpc_id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.lbc.arn
      }
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.lbc]
}

# =============================================================================
# 2. External Secrets Operator(ESO) — Secrets Manager → K8s Secret 동기화(D34).
#    IRSA: external-secrets/external-secrets SA ↔ team1-${env}-eso-role.
#    config의 ClusterSecretStore auth.jwt.serviceAccountRef(external-secrets/external-secrets)와 정합.
# =============================================================================
data "aws_iam_policy_document" "eso_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name                 = "team1-${var.env}-eso-role"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.eso_trust.json
}

data "aws_iam_policy_document" "eso" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    # team1-${env}-* 시크릿(예: team1-prod-jwt-credentials) — 최소권한.
    # ⚠️ ESO secretsmanager resource 미확정(RDS 자동시크릿 접근 보류):
    #   prod ESO는 config prod ExternalSecret에서 DB_USER/DB_PASSWORD를 RDS 자동관리 시크릿
    #   rds!db-ea17e5bc-382e-44dd-9b70-03502aa99eec 에서 읽는다 → 이 패턴(team1-prod-*)엔 매칭 안 됨.
    #   경계(TeamRuntimeBoundary) 검증 후 아래 중 하나를 resources에 추가하여 활성화:
    #     옵션1(와일드카드, 매일 destroy/RDS 재생성에 견고):
    #       "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"
    #       → 공유계정 광역. TeamRuntimeBoundary가 secretsmanager를 team1 범위로 제한하는지 확인 후에만.
    #     옵션2(최소권한, config 핀 UUID 정합 / 재생성 시 갱신 필요):
    #       "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:rds!db-ea17e5bc-382e-44dd-9b70-03502aa99eec-*"
    #   운전자가 작업창에서 get-policy-version으로 경계의 secretsmanager 제한 범위 확인 후 결정.
    #   ※ 이게 확정·활성화되기 전엔 prod DB 자격증명 sync가 동작하지 않음(후속 필수).
    resources = ["arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:team1-${var.env}-*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"] # ListSecrets는 리소스 단위 제한 불가(AWS 제약)
  }
}

resource "aws_iam_role_policy" "eso" {
  name   = "secretsmanager-read"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso.json
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version
  namespace        = "external-secrets"
  create_namespace = true

  values = [yamlencode({
    installCRDs = true # ExternalSecret/ClusterSecretStore CRD 설치(config가 의존)
    serviceAccount = {
      create = true
      name   = "external-secrets"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.eso.arn
      }
    }
  })]
}

# =============================================================================
# 3. Prometheus Redis Exporter — mod:queue 길이(LLEN) → 헤드라인 "큐 깊이" 대시보드 패널.
#    ServiceMonitor release 라벨을 kube-prometheus-stack에 맞춰야 스크레이프됨(DESIGN B-5).
# =============================================================================
resource "helm_release" "redis_exporter" {
  name       = "redis-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-redis-exporter"
  version    = var.redis_exporter_chart_version
  namespace  = "monitoring"

  values = [yamlencode({
    redisAddress = "redis://${local.redis_endpoint}:${local.redis_port}"
    extraArgs = {
      "check-keys" = "mod:queue"
    }
    serviceMonitor = {
      enabled = true
      labels = {
        release = "kube-prometheus-stack" # Prometheus가 이 라벨로 ServiceMonitor를 선택(B-5)
      }
    }
  })]

  depends_on = [helm_release.prometheus_stack]
}
