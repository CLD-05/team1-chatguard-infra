# envs/dev/infra-base/outputs.tf

output "slack_webhook_secret_arn" {
  value       = aws_secretsmanager_secret.slack_webhook.arn
  description = "비용 알람 람다가 참조할 Secrets Manager ARN"
}
