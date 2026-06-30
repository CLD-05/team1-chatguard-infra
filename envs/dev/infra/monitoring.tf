# envs/dev/infra/monitoring.tf

# 1. 비상 알림 통로 
resource "aws_sns_topic" "cloudwatch_alert_topic" {
  name = "team1-dev-cloudwatch-alert-topic"
  tags = { Team = "team1" }
}

# 2. AWS 챗봇 슬랙 중계기 개설
module "observability_cloudwatch" {
  source         = "../../../modules/observability-cloudwatch"
  db_instance_id = module.database.db_instance_id

  slack_workspace_id = var.slack_workspace_id
  slack_channel_id   = var.slack_channel_id
}
