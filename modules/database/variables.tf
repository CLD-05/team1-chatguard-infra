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

variable "allowed_security_groups" {
  description = "RDS에 접근을 허용할 보안 그룹 ID 리스트 (EKS 노드, Bastion 등)"
  type        = list(string)
}

variable "instance_class" {
  description = "DB 인스턴스 사양 (dev: db.t4g.micro 등)"
  type        = string
  default     = "db.t4g.micro"
}
