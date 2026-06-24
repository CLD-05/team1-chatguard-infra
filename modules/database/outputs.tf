output "db_endpoint" {
  description = "백엔드 애플리케이션이 연결할 RDS 엔드포인트 주소"
  value       = aws_db_instance.this.endpoint
}

output "rds_master_user_secret_arn" {
  description = "AWS RDS가 자체 생성하여 관리하는 마스터 비밀번호 시크릿의 ARN"
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}

output "db_username" {
  description = "데이터베이스 마스터 유저네임"
  value       = aws_db_instance.this.username
}

# ------------------------------------------------------------------------------
# AWS 완전관리형 Secrets Manager ARN 출력 (dev/prod 공통 적용)
# ------------------------------------------------------------------------------
output "db_secret_arn" {
  description = "AWS Secrets Manager가 자동 생성한 마스터 패스워드 금고 ARN"
  value       = one(aws_db_instance.this.master_user_secret[*].secret_arn)
}
