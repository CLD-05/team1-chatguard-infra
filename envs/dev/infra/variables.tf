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

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "EKS 클러스터 Endpoint에 접근을 허용할 승인된 공인 IP 대역 리스트"
  default     = ["0.0.0.0/0"] # dev는 기본값으로 전체 오픈
}
