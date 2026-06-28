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

variable "deletion_protection" {
  type        = bool
  description = "데이터베이스 임의 삭제 방지 활성화 여부"
  default     = false # dev 환경은 쉽게 지울 수 있게 false 기본값
}

variable "skip_final_snapshot" {
  type        = bool
  description = "DB 삭제 시 최종 스냅샷 생성 건너뛰기 여부"
  default     = true # dev 환경은 스냅샷 없이 빠르게 지우도록 true 기본값
}

variable "backup_retention_period" {
  type        = number
  description = "자동 백업 보존 기간 (일 단위)"
  default     = 0 # dev 환경은 백업 비용을 아끼기 위해 0일 기본값
}

variable "multi_az" {
  type        = bool
  description = "다중 가용구역(Multi-AZ) 고가용성 복제 활성화 여부"
  default     = false # dev 환경은 단일 AZ로 비용 최적화
}

# D54-a: skip_final_snapshot=false(prod)일 때 필요한 최종 스냅샷 식별자. dev는 skip=true라 null로 무관 → plan 변화 0.
variable "final_snapshot_identifier" {
  type        = string
  description = "DB 삭제/교체 시 생성할 최종 스냅샷 이름(prod 보존용). dev는 default null."
  default     = null
}
