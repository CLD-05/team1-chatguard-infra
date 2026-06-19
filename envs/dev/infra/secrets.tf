# =========================================================================
# AWS Secrets Manager 금고(Secret) 본체 선언
# =========================================================================
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${local.name_prefix}-database-credentials"
  description             = "ChatGuard dev 환경 RDS MySQL 마스터 자격 증명 금고"
  recovery_window_in_days = 0 # dev 환경이므로 테라폼 destroy 시 즉시 삭제 허용 (비용 방어)

  tags = {
    Name = "${local.name_prefix}-database-credentials"
  }
}

# =========================================================================
# 개발계(dev) 단일 시크릿 버전 관리 (충돌 방지 및 비밀번호 State 노출 차단)
# =========================================================================
resource "aws_secretsmanager_secret_version" "chatguard_secret_content" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    REDIS_HOST = module.elasticache.redis_endpoint
    REDIS_PORT = module.elasticache.redis_port
    DB_URL     = "jdbc:mysql://${module.database.db_endpoint}/${var.db_name}?useSSL=false&allowPublicKeyRetrieval=true"
  })
}

# =========================================================================
# 3. Grafana 관리자용 독립 금고 선언 
# =========================================================================
resource "aws_secretsmanager_secret" "grafana_secret" {
  name                    = "${local.name_prefix}-grafana-credentials"
  description             = "ChatGuard dev 환경 Grafana 대시보드 어드민 자격 증명 금고"
  recovery_window_in_days = 0 # dev 비용 방어

  tags = {
    Name = "${local.name_prefix}-grafana-credentials"
  }
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
