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
    # 경계(TeamRuntimeBoundary)는 secretsmanager를 team1-*로 제한하지 않음(NotAction 방식 — 위험 IAM·결제·리전만
    # 차단, secretsmanager는 Resource:* 허용) → 다른 팀 격리 책임은 본 정책 자신에게 있다.
    # team1-${env}-*: jwt-credentials 등. rds!db-*: config prod ExternalSecret이 DB_USER/DB_PASSWORD를 읽는
    #   RDS 자동관리 시크릿(rds!db-ea17e5bc-…). UUID가 매일 destroy로 변동 → 와일드카드 불가피(계정·리전 한정).
    # ★잔여 노출(빚): 같은 계정 다른 팀 RDS 시크릿 조회 권한 존재(현실 조회는 config가 핀한 우리 UUID뿐).
    #   최소권한 회복 = D56(RDS state 분리로 UUID 영속) 후 특정 UUID 핀(옵션2)으로 좁힐 것.
    resources = [
      "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:team1-${var.env}-*",
      "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:rds!db-*",
    ]
  }

  # RDS 자동관리 시크릿(rds!db-…)은 KMS(aws/secretsmanager 관리키)로 암호화 → ESO 복호화 권한 필요.
  # database 모듈이 커스텀 KMS 미지정 → account·region 단위 aws/secretsmanager 관리키 1개로 고정
  #   (이 키가 RDS 자동시크릿·team1-prod-* 모두를 암호화. 2026-06-30 describe-key로 ARN 확인).
  # resource를 그 키 ARN으로 한정 + ViaService(Secrets Manager 경유)로 이중 제한 → ["*"] 과확장 회피.
  statement {
    sid     = "DecryptSecretsViaSecretsManager"
    effect  = "Allow"
    actions = ["kms:Decrypt"]
    # aws/secretsmanager 관리형 키 — 계정·리전당 고정, 매일 destroy/apply에도 ARN 불변(RDS UUID와 달리).
    resources = ["arn:aws:kms:ap-northeast-2:495599735720:key/b9cbb661-534e-47ff-a751-6e1b8c80271e"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.ap-northeast-2.amazonaws.com"]
    }
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
