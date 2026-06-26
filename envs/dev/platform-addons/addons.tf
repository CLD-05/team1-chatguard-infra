# envs/dev/platform-addons/addons.tf
# Phase 0 — 부하/스케일/가용성 테스트의 전제가 되는 플랫폼 애드온.
# DESIGN A-1(Terraform vs GitOps 경계): Helm 설치(KEDA·ESO·LBC·redis_exporter)는 Terraform 소유.
#   ScaledObject/ServiceMonitor 등 K8s 리소스는 GitOps(config)가 소유 — 여기선 "컨트롤러 설치"만.
# main.tf(ArgoCD·kube-prometheus-stack)와 같은 모듈, 파일만 분리해 diff를 깔끔히 유지.
#
# 의존(providers.tf/main.tf에 이미 선언된 것 재사용):
#   - data.terraform_remote_state.infra  → oidc_provider_arn·oidc_provider_url·vpc_id·redis_endpoint·redis_port
#   - data.aws_eks_cluster.this          → 클러스터 이름
#   - data.aws_caller_identity.current   → account id

locals {
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.infra.outputs.oidc_provider_url # https:// 제거된 형태
  vpc_id            = data.terraform_remote_state.infra.outputs.vpc_id
  redis_endpoint    = data.terraform_remote_state.infra.outputs.redis_endpoint
  redis_port        = data.terraform_remote_state.infra.outputs.redis_port
  cluster_name      = data.aws_eks_cluster.this.name
}

# =============================================================================
# 1. KEDA — 큐 깊이(mod:queue) 기반 워커 오토스케일(헤드라인 데모, DESIGN D12·D13)
#    Redis 스케일러는 KEDA가 Redis에 직접 접속 → AWS 권한(IRSA) 불필요.
#    ScaledObject 자체는 config(GitOps)가 소유 — 여기선 컨트롤러만 설치.
# =============================================================================
resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.keda_chart_version
  namespace        = "keda"
  create_namespace = true
}

# =============================================================================
# 2. AWS Load Balancer Controller(LBC) — Ingress(class=alb)가 ALB를 실제로 프로비저닝하게 함.
#    이게 있어야 D47(ALB 직결)·D18(LOR)·D15(드레인)가 작동(현재 미설치라 ALB 자체가 안 뜸).
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
# 3. External Secrets Operator(ESO) — Secrets Manager → K8s Secret 자동 동기화(D34 최종형).
#    IRSA: external-secrets/external-secrets SA ↔ team1-${env}-eso-role(team1-${env}-* 시크릿만 read).
#    config의 ClusterSecretStore auth.jwt.serviceAccountRef(external-secrets/external-secrets)와 정합 —
#    그 SA에 role-arn 어노테이션을 달면 ESO가 해당 role을 AssumeRoleWithWebIdentity 한다.
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
    # team1-${env}-* 시크릿만 — 최소권한(다른 팀/환경 시크릿 접근 차단).
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
# 4. Prometheus Redis Exporter — mod:queue 길이(LLEN) 등 Redis 메트릭 → 헤드라인 대시보드.
#    KEDA는 Redis를 직접 읽어 스케일하지만, "큐 깊이" 패널 시각화는 이 exporter가 공급(B-2/B-3).
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
    # mod:queue LLEN을 redis_key_size{key="mod:queue"}로 노출 → "큐 깊이" 대시보드 패널(B-2/B-3).
    # 렌더링 결과 = exporter 인자 --check-keys=mod:queue. KEDA 스케일과 무관(KEDA는 Redis 직독).
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
