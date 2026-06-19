resource "aws_secretsmanager_secret" "redis_secret" {
  name                    = "team1-prod-redis-secrets"
  description             = "ChatGuard prod 환경 Redis 연결 정보 금고"
  recovery_window_in_days = 7
}

# =========================================================================
# ArgoCD EKS 조작을 위한 관리자 IAM 역할 생성
# =========================================================================
resource "aws_iam_role" "eks_admin_role" {
  name = "team1-${var.env}-eks-admin-role"

  permissions_boundary = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

# 역할에 실제 관리자 권한 매핑
resource "aws_iam_role_policy_attachment" "eks_admin_policy" {
  role       = aws_iam_role.eks_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_caller_identity" "current" {}
