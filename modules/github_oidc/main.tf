# modules/github_oidc/main.tf
#
# GitHub Actions가 OIDC로 AWS에 들어와 ECR에 이미지를 push할 수 있게 하는 모듈.
# 구성: (1) OIDC Provider 등록  (2) AssumeRole 가능한 IAM Role  (3) ECR push 최소 권한.

locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
  oidc_audience   = "sts.amazonaws.com"

  # Trust Policy의 StringLike 조건에 들어갈 sub 목록.
  #  - 브랜치: repo:CLD-05/team1-chatguard-app:ref:refs/heads/main (허용 브랜치마다 한 줄)
  #  - environment: repo:...:environment:production (environment 선언 job — 승인 게이트 통과분만)
  # ⚠️ 두 목록이 모두 비면 condition values가 빈 배열 → 정책 오류. 호출부가 최소 한쪽은 채울 것.
  allowed_subs = concat(
    [
      for b in var.allowed_branches :
      "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${b}"
    ],
    [
      for e in var.allowed_environments :
      "repo:${var.github_org}/${var.github_repo}:environment:${e}"
    ],
  )

  # provider를 새로 만들면 그 ARN, 아니면 기존 것을 data로 조회한 ARN.
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# --- (1) OIDC Provider ---------------------------------------------------------
# 계정당 token.actions.githubusercontent.com 은 단 1개만 존재 가능(URL이 식별자).
# 6팀 공유 계정이라 다른 팀이 이미 만들었을 수 있다 → create_oidc_provider 토글로 분기.

# 이미 존재하는 경우: 참조만 한다(생성 안 함).
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.github_oidc_url
}

# 존재하지 않는 경우: 우리가 만든다(다른 팀과 공유됨).
# thumbprint_list 생략: 2024-12 이후 AWS가 GitHub을 root CA로 신뢰하므로 검증에 미사용.
# (구버전 AWS provider에서 required 에러가 나면 아래 data.tls_certificate 패턴으로 대체)
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = local.github_oidc_url
  client_id_list  = [local.oidc_audience]
  thumbprint_list = []

  tags = merge(var.tags, { Name = "github-actions-oidc" })
}

# --- (2) IAM Role: GitHub Actions가 AssumeRoleWithWebIdentity로 가져갈 역할 -------
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    # audience 고정: 우리 토큰의 aud == sts.amazonaws.com 이어야 함
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [local.oidc_audience]
    }

    # 핵심 보안 조건: 우리 repo의 허용 브랜치에서 온 토큰만 통과
    # (이게 없으면 GitHub의 아무 repo나 이 role을 가져갈 수 있다)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subs
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  permissions_boundary = var.permissions_boundary_arn # CLAUDE.md §1-7: 없으면 apply 거부
  tags                 = var.tags
}

# --- (3) ECR push 최소 권한 ----------------------------------------------------
data "aws_iam_policy_document" "ecr_push" {
  # GetAuthorizationToken은 리소스 범위 지정 불가 → 별도 statement에서 "*"
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # 실제 push 동작은 우리 3개 ECR repo로만 제한
  statement {
    sid    = "EcrPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
    ]
    resources = var.ecr_repository_arns
  }

  # (선택) 다른 env ECR에서 pull만 허용 — 이미지 승격(crane copy)의 소스 read 최소권한.
  # push 계열 액션은 위 EcrPush의 대상(자기 env repo)에만 남는다.
  dynamic "statement" {
    for_each = length(var.ecr_pull_repository_arns) > 0 ? [1] : []
    content {
      sid    = "EcrPullPromotionSource"
      effect = "Allow"
      actions = [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability",
      ]
      resources = var.ecr_pull_repository_arns
    }
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
