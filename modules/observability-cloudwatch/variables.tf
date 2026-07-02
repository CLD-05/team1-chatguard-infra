# modules/observability-cloudwatch/variables.tf

variable "db_instance_id" {
  type        = string
  description = "감시할 RDS DB 식별자"
}

variable "slack_workspace_id" {
  description = "AWS 챗봇과 연동할 슬랙 워크스페이스 고유 ID"
  type        = string
}

variable "slack_channel_id" {
  description = "비용 알람을 받을 슬랙 채널 고유 ID"
  type        = string
}

variable "env" {
  type        = string
  description = "배포 환경 (dev 또는 prod)"
}
