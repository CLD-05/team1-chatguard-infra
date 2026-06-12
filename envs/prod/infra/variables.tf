variable "team" {
  description = "팀 식별자 (명세서 규약: team1)"
  type        = string
}

variable "env" {
  description = "인프라 환경 (prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC의 메인 IP 대역"
  type        = string
}

variable "eks_instance_types" {
  description = "EKS 워커 노드 EC2 인스턴스 타입"
  type        = list(string)
}

variable "eks_desired_size" {
  description = "EKS 워커 노드 목표 개수"
  type        = number
}

variable "rds_instance_class" {
  description = "RDS 데이터베이스 인스턴스 사양"
  type        = string
}

variable "redis_node_type" {
  description = "ElastiCache Redis 노드 사양"
  type        = string
}

variable "domain_name" {
  type        = string
  description = "서비스 창구 도메인 주소"
}
