output "repository_urls" {
  description = "생성된 ECR 리포지토리들의 고유 주소 URL 맵"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}
