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
