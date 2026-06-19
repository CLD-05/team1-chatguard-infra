resource "aws_secretsmanager_secret" "redis_secret" {
  name                    = "${local.name_prefix}-redis-secrets"
  recovery_window_in_days = 0 # 테스트 및 유연한 재빌드를 위해 0으로 설정
}
