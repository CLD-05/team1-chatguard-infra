variable "vpc_cidr" {
  description = "VPC에 할당할 메인 CIDR 블록"
  type        = string
}

variable "vpc_name" {
  description = "VPC 리소스의 Name 태그에 들어갈 이름 (B부류 규칙)"
  type        = string
}

variable "public_subnet_extra_tags" {
  type        = map(string)
  default     = {}
  description = "public 서브넷에 추가할 환경별 태그(예: kubernetes.io/role/elb). 모듈을 환경 무관하게 유지하기 위해 값은 호출측 envs에서 주입 — CLAUDE.md §3"
}

# D54: 서브넷·NAT를 배치할 AZ 명시 리스트(길이 = AZ 수). data source 대신 명시 리스트로 AZ를 고정 →
#   의도 외 AZ 이동 방지(예: dev 2c가 2b로 바뀌는 일 차단). default 없음 — 호출측 envs에서 주입(CLAUDE §3).
variable "availability_zones" {
  type        = list(string)
  description = "서브넷·NAT를 배치할 가용영역 명시 리스트. 예: dev [\"ap-northeast-2a\",\"ap-northeast-2c\"], prod 3개."
}

# D54: true=NAT 1개 공유(dev, 비용). false=AZ별 NAT + AZ별 private RT(prod HA, FIS AZ장애 데모 전제).
variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "true=NAT 게이트웨이 1개를 모든 private 서브넷이 공유(비용 최적·dev). false=AZ당 NAT 1개 + AZ별 private RT(HA·prod)."
}
