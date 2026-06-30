# modules/observability-cloudwatch/main.tf

# 1. 모듈 내부에서 DB 알람용 SNS 통로를 직접 개설
resource "aws_sns_topic" "db_alert_topic" {
  name = "team1-dev-db-alert-topic"
  tags = { Team = "team1" }
}

# 2. 모듈 내부에서 DB 알람 전용 AWS Chatbot 슬랙 중계기 개설
resource "aws_chatbot_slack_channel_configuration" "db_slack_notifier" {
  configuration_name = "team1-dev-db-slack-chatbot"
  iam_role_arn       = "arn:aws:iam::495599735720:role/TeamRuntimeBoundary"
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_workspace_id

  sns_topic_arns = [
    aws_sns_topic.db_alert_topic.arn
  ]

  tags = { Team = "team1" }
}

# 3. DB 연결 수 알람 본체
resource "aws_cloudwatch_metric_alarm" "db_connection_alarm" {
  alarm_name          = "team1-dev-rds-high-connections"
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

  tags = { Team = "team1" }
}
