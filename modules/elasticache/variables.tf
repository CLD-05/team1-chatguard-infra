variable "cache_name" {
  description = "ElastiCache Redis 클러스터 식별자 이름 (team1-dev-redis 등)"
  type        = string
}

variable "vpc_id" {
  description = "Redis가 속할 VPC ID"
  type        = string
}

variable "isolated_subnet_ids" {
  description = "Redis가 들어설 완전 격리망(Isolated) 서브넷 ID 목록"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "EKS 워커 노드의 보안 그룹 ID 리스트 (이 그룹만 Redis 접근 허용)"
  type        = list(string)
}

variable "node_type" {
  description = "Redis 노드 사양 (dev: cache.t4g.micro 등)"
  type        = string
  default     = "cache.t4g.micro"
}

# D54-a: prod HA용 변수. default = 현행 dev값(단일·failover 없음) → dev는 미주입 시 plan 변화 0. prod caller만 HA값 주입.
variable "num_cache_clusters" {
  description = "replication group 노드 수(primary+replica). prod HA는 2 이상."
  type        = number
  default     = 1
}

variable "automatic_failover_enabled" {
  description = "primary 장애 시 replica 자동 승격(노드 2 이상 필요)."
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "replica를 다른 AZ에 배치(Multi-AZ). automatic_failover_enabled와 함께 사용."
  type        = bool
  default     = false
}
