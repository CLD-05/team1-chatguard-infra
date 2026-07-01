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

resource "aws_cloudwatch_metric_alarm" "billing_prediction_alarm" {
  provider = aws.us_east_1

  alarm_name          = "team1-${var.env}-billing-estimated-charges"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "21600" # 결제 지표는 하루에 몇 번 안 갱신되므로 6시간(21600초) 주기로 체크
  statistic           = "Maximum"
  threshold           = "10" # [테스트용 수치] 누적 금액이 10달러를 넘으면 알람 발생

  alarm_description = "프로젝트 dev 환경 누적 결제 금액이 설정치($10)를 초과했습니다. 비용을 확인하세요!"

  alarm_actions = [aws_sns_topic.db_alert_topic.arn]

  dimensions = {
    Currency = "USD"
  }
}
