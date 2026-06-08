variable "db_name" {
  description = "RDS MySQL 식별자 이름 (team1-dev-db 등)"
  type        = string
}

variable "vpc_id" {
  description = "RDS가 속할 VPC ID"
  type        = string
}

variable "isolated_subnet_ids" {
  description = "RDS가 들어설 완전 격리망(Isolated) 서브넷 ID 목록"
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "EKS 워커 노드의 보안 그룹 ID (이 그룹만 DB 접근 허용)"
  type        = string
}

variable "instance_class" {
  description = "DB 인스턴스 사양 (dev: db.t4g.micro 등)"
  type        = string
  default     = "db.t4g.micro"
}
