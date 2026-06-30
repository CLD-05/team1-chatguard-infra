# modules/observability-cloudwatch/main.tf

resource "aws_sns_topic" "db_alert_topic" {
  name = "team1-${var.env}-db-alert-topic"
}

data "aws_iam_policy_document" "chatbot_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "chatbot_role" {
  name                 = "team1-${var.env}-chatbot-role"
  permissions_boundary = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"
  assume_role_policy   = data.aws_iam_policy_document.chatbot_assume.json
}

resource "aws_chatbot_slack_channel_configuration" "db_slack_notifier" {
  configuration_name = "team1-${var.env}-db-slack-chatbot"
  iam_role_arn       = aws_iam_role.chatbot_role.arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_workspace_id

  sns_topic_arns = [
    aws_sns_topic.db_alert_topic.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "db_connection_alarm" {
  alarm_name          = "team1-${var.env}-rds-high-connections"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "RDS 동시 연결 수가 위험 수위(70개)에 도달했습니다."

  alarm_actions = [aws_sns_topic.db_alert_topic.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}
