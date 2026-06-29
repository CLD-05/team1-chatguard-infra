# envs/prod/infra/outputs.tf

output "rds_secret_arn" {
  description = "AWS가 자동으로 생성한 prod 환경 RDS 마스터 패스워드 Secrets Manager ARN"
  value       = module.database.db_secret_arn
}

output "rds_endpoint" {
  description = "prod 환경 RDS MySQL 연결 엔드포인트 주소"
  value       = module.database.db_endpoint
}

# ---- platform-addons(PR-2: LBC·ESO·redis_exporter)가 remote_state로 참조하는 값들 ----
# ★ 출력 이름은 dev/infra/outputs.tf와 글자 단위 동일 — prod/platform-addons가 dev와 같은 키로 읽음.

output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS 클러스터 API 엔드포인트 주소"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "EKS 클러스터 CA 인증서 데이터"
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "VPC ID — LBC helm values(vpcId)에서 사용"
  value       = module.network.vpc_id
}

output "oidc_provider_arn" {
  description = "EKS IRSA용 OIDC provider ARN — LBC·ESO trust policy의 Federated principal"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL(https:// 제거) — IRSA trust 조건 키(:aud/:sub)"
  value       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "redis_endpoint" {
  description = "ElastiCache Redis 기본 엔드포인트 — redis_exporter redisAddress"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "Redis 포트"
  value       = module.elasticache.redis_port
}

output "chat_server_s3_role_arn" {
  description = "채팅 서버 S3 읽기 권한을 가지는 IAM 역할의 ARN"
  value       = aws_iam_role.chat_server_s3_role.arn
}
