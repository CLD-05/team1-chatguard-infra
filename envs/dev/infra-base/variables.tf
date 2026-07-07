# envs/dev/infra-base/variables.tf

variable "slack_workspace_id" {
  type        = string
  description = "AWS 챗봇과 연동할 슬랙 워크스페이스 고유 ID"
  default     = ""
}

variable "slack_channel_id" {
  type        = string
  description = "비용 알람을 받을 슬랙 채널 고유 ID"
  default     = ""
}

variable "db_slack_channel_id" {
  type        = string
  description = "DB 경보 알림을 수신할 모니터링 슬랙 채널 ID"
  default     = ""
}

variable "env" {
  type        = string
  description = "배포 환경 (dev 또는 prod)"
  default     = "dev"
}
