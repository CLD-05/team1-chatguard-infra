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

variable "eks_node_security_group_id" {
  description = "EKS 워커 노드의 보안 그룹 ID (이 그룹만 Redis 접근 허용)"
  type        = string
}

variable "node_type" {
  description = "Redis 노드 사양 (dev: cache.t4g.micro 등)"
  type        = string
  default     = "cache.t4g.micro"
}
