output "db_endpoint" {
  description = "백엔드 애플리케이션이 연결할 RDS 엔드포인트 주소"
  value       = aws_db_instance.this.endpoint
}

output "db_username" {
  description = "데이터베이스 마스터 유저네임"
  value       = aws_db_instance.this.username
}

output "db_password" {
  description = "dev일 때만 비밀번호를 출력하고, prod일 때는 빈 값을 반환하여 장부를 보호합니다."
  value       = var.environment == "prod" ? "" : random_password.password[0].result
  sensitive   = true
}

