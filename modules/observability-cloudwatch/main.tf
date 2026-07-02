# modules/observability-cloudwatch/main.tf

resource "aws_sns_topic" "db_alert_topic" {
  name              = "team1-${var.env}-db-alert-topic"
  kms_master_key_id = "alias/aws/sns"
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

# =========================================================================
# 서울 리전 전용 Lambda 기반 우회 비용 알람 시스템
# =========================================================================

# Lambda 함수가 비용을 조회하고 슬랙을 쏠 수 있는 권한(Role) 생성
resource "aws_iam_role" "billing_lambda_role" {
  name                 = "team1-${var.env}-billing-lambda-role"
  permissions_boundary = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 비용 조회(Cost Explorer) 및 로그 기록 권한 부여
resource "aws_iam_role_policy" "billing_lambda_policy" {
  name = "team1-${var.env}-billing-lambda-policy"
  role = aws_iam_role.billing_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ce:GetCostAndUsage"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ap-northeast-2:495599735720:log-group:/aws/lambda/team1-${var.env}-billing-alert-lambda:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.slack_webhook_secret_arn
      }
    ]
  })
}

# 실제 작동할 Python 코드 압축 아티팩트 지정
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/files/billing_script.zip"

  source {
    content  = file("${path.module}/files/billing_script.py")
    filename = "billing_script.py"
  }
}

# 서울 리전에 생성될 Lambda 함수 본체
resource "aws_lambda_function" "billing_alert_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "team1-${var.env}-billing-alert-lambda"
  role             = aws_iam_role.billing_lambda_role.arn
  handler          = "billing_script.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      SECRET_ARN = var.slack_webhook_secret_arn
      ENV        = var.env
    }
  }
}

# 매일 자동으로 실행되게 만드는 알람 시계 (EventBridge)
resource "aws_cloudwatch_event_rule" "daily_billing_cron" {
  name                = "team1-${var.env}-daily-billing-cron"
  description         = "매일 정기적으로 비용 조회를 트리거합니다."
  schedule_expression = "cron(0 0 * * ? *)" # 한국 시간 오전 9시 정기 실행
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_billing_cron.name
  target_id = "TriggerBillingLambda"
  arn       = aws_lambda_function.billing_alert_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_alert_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_billing_cron.arn
}
