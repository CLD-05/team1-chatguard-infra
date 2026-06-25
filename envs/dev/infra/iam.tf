# envs/dev/infra/iam.tf

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
      values   = ["system:serviceaccount:chatguard:team1-dev-api-server-sa"]
    }
  }
}

resource "aws_iam_role" "chat_server_s3_role" {
  name                 = "team1-dev-chat-server-s3-role"
  permissions_boundary = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"
  assume_role_policy   = data.aws_iam_policy_document.chat_server_s3_trust.json

  tags = {
    Team        = "team1"
    Environment = "dev"
    Project     = "chatguard"
  }
}

resource "aws_iam_role_policy" "chat_server_s3_readonly" {
  name = "team1-dev-chat-server-s3-readonly"
  role = aws_iam_role.chat_server_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::team1-dev-chatguard-assets",
        "arn:aws:s3:::team1-dev-chatguard-assets/*",
        "arn:aws:s3:::team1-dev-chatguard-migration",
        "arn:aws:s3:::team1-dev-chatguard-migration/*"
      ]
    }]
  })
}
