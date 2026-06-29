# envs/prod/infra/iam.tf
# chat-server(api-server) Pod가 정적 키 없이 S3를 읽도록 하는 IRSA(IAM Role for ServiceAccount).
# dev/infra/iam.tf 복제 — 이름/참조만 prod. boundary는 prod 루트 관례(var.iam_role_permissions_boundary).

data "aws_iam_policy_document" "chat_server_s3_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      # config 레포 namePrefix=team1-prod- → base SA 'api-server-sa' 가 prod에선 team1-prod-api-server-sa.
      values = ["system:serviceaccount:chatguard:team1-prod-api-server-sa"]
    }
  }
}

resource "aws_iam_role" "chat_server_s3_role" {
  name                 = "team1-prod-chat-server-s3-role"
  permissions_boundary = var.iam_role_permissions_boundary # CLAUDE §1-7: 미부착 시 apply 거부
  assume_role_policy   = data.aws_iam_policy_document.chat_server_s3_trust.json

  tags = {
    Team        = "team1"
    Environment = "prod"
    Project     = "chatguard"
  }
}

resource "aws_iam_role_policy" "chat_server_s3_readonly" {
  name = "team1-prod-chat-server-s3-readonly"
  role = aws_iam_role.chat_server_s3_role.id

  # prod엔 chatguard-assets 버킷이 없다 → 미디어는 team1-prod-images(module.s3_images).
  # 금칙어 시드는 banned_words 버킷(main.tf, D51).
  # 하드코딩 ARN 대신 리소스/모듈 참조 → 버킷명 변경 시 정책 자동 추종(silent break 방지).
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        module.s3_images.bucket_arn,
        "${module.s3_images.bucket_arn}/*",
        aws_s3_bucket.banned_words_bucket.arn,
        "${aws_s3_bucket.banned_words_bucket.arn}/*"
      ]
    }]
  })
}
