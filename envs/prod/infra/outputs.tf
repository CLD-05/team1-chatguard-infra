# envs/prod/infra/outputs.tf

output "rds_secret_arn" {
  description = "AWS가 자동으로 생성한 prod 환경 RDS 마스터 패스워드 Secrets Manager ARN"
  value       = module.database.db_secret_arn
}

output "rds_endpoint" {
  description = "prod 환경 RDS MySQL 연결 엔드포인트 주소"
  value       = module.database.db_endpoint
}
