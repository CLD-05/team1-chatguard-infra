# modules/github_oidc/outputs.tf

output "role_arn" {
  description = "GitHub Actions가 role-to-assume에 넣을 ARN. deploy.yml의 AWS_ROLE_ARN과 일치."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "생성된 IAM role 이름."
  value       = aws_iam_role.this.name
}

output "oidc_provider_arn" {
  description = "사용된 OIDC Provider ARN(신규 생성 또는 기존 참조)."
  value       = local.oidc_provider_arn
}
