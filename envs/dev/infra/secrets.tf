resource "random_password" "grafana_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# =========================================================================
# 1. AWS Secrets Manager 금고(Secret) 본체 선언
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
# 4. Grafana 금고 내부에 들어갈 독립 시크릿 채우기
# =========================================================================
resource "aws_secretsmanager_secret_version" "grafana_secret_val" {
  secret_id = aws_secretsmanager_secret.grafana_secret.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.grafana_password.result
  })
}
