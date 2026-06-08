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
# 2. 금고 내부에 들어갈 초민감 데이터 채우기 (Secret Version)
# =========================================================================
# 기존 database 모듈에서 생성한 random_password와 마스터 계정 정보를 JSON으로 묶어 금고에 인입합니다.
resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = module.database.db_endpoint # database 모듈의 출력값 참조
    port     = 3306
    username = "admin"
    password = module.database.db_password # database 모듈의 평문 패스워드 추출값
  })
}
