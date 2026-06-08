output "db_endpoint" {
  description = "백엔드 애플리케이션이 연결할 RDS 엔드포인트 주소"
  value       = aws_db_instance.this.endpoint
}

output "db_username" {
  description = "데이터베이스 마스터 유저네임"
  value       = aws_db_instance.this.username
}

output "db_password" {
  description = "임의 생성된 데이터베이스 마스터 패스워드 (민감 정보 보호)"
  value       = random_password.password.result
  sensitive   = true
}

