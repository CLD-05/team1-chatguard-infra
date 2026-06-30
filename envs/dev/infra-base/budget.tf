# envs/dev/infra-base/budget.tf

# 1. 비용 알람 전용 SNS 통로 (1층 방에 독립 개설)
resource "aws_sns_topic" "budget_alert_topic" {
  name = "team1-dev-budget-alert-topic"
  tags = { Team = "team1" }
}

# 비용 알람용 Chatbot 전용 IAM 역할 직접 생성
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
  name                 = "team1-dev-budget-chatbot-role"
  permissions_boundary = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"
  assume_role_policy   = data.aws_iam_policy_document.budget_chatbot_assume.json
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSServiceRoleForAWSChatbot"]
}

# 2. 비용 알람 전용 AWS Chatbot 슬랙 중계기 개설
resource "aws_chatbot_slack_channel_configuration" "budget_slack_notifier" {
  configuration_name = "team1-dev-budget-slack-chatbot"
  iam_role_arn       = aws_iam_role.budget_chatbot_role.arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_workspace_id

  sns_topic_arns = [
    aws_sns_topic.budget_alert_topic.arn
  ]

  tags = { Team = "team1" }
}

# 3. 비용 알람 본체
resource "aws_budgets_budget" "team_cost_budget" {
  name              = "team1-dev-budget"
  budget_type       = "COST"
  limit_amount      = "100"
  limit_unit        = "USD"
  time_period_start = "2026-01-01_00:00"
  time_unit         = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["Team$team1"]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 80
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    subscriber_sns_topic_arns = [aws_sns_topic.budget_alert_topic.arn]
  }
}
