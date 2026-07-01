variable "team" {
  description = "팀 식별자 (예: team1)"
  type        = string
}

variable "env" {
  description = "인프라 환경 (dev / prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC의 메인 IP 대역"
  type        = string
}

# D54: network 모듈로 전달. dev=2AZ(2b 제외)·단일 NAT. 값은 tfvars에서 명시(team·env·vpc_cidr와 동일 패턴).
variable "availability_zones" {
  description = "서브넷·NAT를 배치할 AZ 명시 리스트(길이 = AZ 수). dev=2AZ, prod=3AZ."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true=NAT 1개 공유(dev, 비용). false=AZ별 NAT(prod HA). D54."
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "EKS 클러스터 Endpoint에 접근을 허용할 승인된 공인 IP 대역 리스트"
  default     = ["0.0.0.0/0"] # dev는 기본값으로 전체 오픈
}

variable "eks_cluster_admin_principals" {
  description = "EKS 클러스터 관리자 접근 IAM 유저 ARN 목록(팀원)."
  type        = list(string)
  default = [
    "arn:aws:iam::495599735720:user/team1-ykh",
    "arn:aws:iam::495599735720:user/team1-ssm",
    "arn:aws:iam::495599735720:user/team1-lhc",
    "arn:aws:iam::495599735720:user/team1-kwy",
    "arn:aws:iam::495599735720:user/team1-cjc",
  ]
}

variable "db_name" {
  type        = string
  description = "MySQL 데이터베이스 이름"
  default     = "chatguard"
}

variable "slack_workspace_id" {
  type        = string
  description = "AWS 챗봇과 연동할 슬랙 워크스페이스(팀)의 고유 ID"
  default     = ""
}

variable "slack_channel_id" {
  type        = string
  description = "알람 경보 메시지를 받을 슬랙 채널(단톡방)의 고유 ID"
  default     = ""
}

variable "slack_webhook_url" {
  type        = string
  description = "Lambda 기반 비용 리포트 전송을 위한 슬랙 Incoming Webhook URL"
  sensitive   = true
}
