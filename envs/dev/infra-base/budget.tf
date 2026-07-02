# envs/dev/infra-base/budget.tf

resource "aws_sns_topic" "budget_alert_topic" {
  name              = "team1-${var.env}-budget-alert-topic"
  kms_master_key_id = "alias/aws/sns"
}

data "aws_iam_policy_document" "budget_chatbot_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "budget_chatbot_role" {
  name                 = "team1-${var.env}-budget-chatbot-role"
  permissions_boundary = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"
  assume_role_policy   = data.aws_iam_policy_document.budget_chatbot_assume.json
}

resource "aws_chatbot_slack_channel_configuration" "budget_slack_notifier" {
  configuration_name = "team1-${var.env}-budget-slack-chatbot"
  iam_role_arn       = aws_iam_role.budget_chatbot_role.arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_workspace_id

  sns_topic_arns = [
    aws_sns_topic.budget_alert_topic.arn
  ]
}

# AWS Secrets Manager에 비밀 금고 개설
resource "aws_secretsmanager_secret" "slack_webhook" {
  name                    = "team1-${var.env}-slack-webhook-url"
  recovery_window_in_days = var.env == "prod" ? 7 : 0
}
