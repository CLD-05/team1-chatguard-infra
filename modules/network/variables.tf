variable "vpc_cidr" {
  description = "VPC에 할당할 메인 CIDR 블록"
  type        = string
}

variable "vpc_name" {
  description = "VPC 리소스의 Name 태그에 들어갈 이름 (B부류 규칙)"
  type        = string
}

variable "environment" {
  description = "환경 구분 (dev 또는 prod)"
  type        = string
}

variable "public_subnet_extra_tags" {
  type        = map(string)
  default     = {}
  description = "public 서브넷에 추가할 환경별 태그(예: kubernetes.io/role/elb). 모듈을 환경 무관하게 유지하기 위해 값은 호출측 envs에서 주입 — CLAUDE.md §3"
}
