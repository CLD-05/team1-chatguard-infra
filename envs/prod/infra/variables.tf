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

variable "iam_role_permissions_boundary" {
  type        = string
  description = "IAM Role생성 규제용 Permissions Boundary ARN"
  default     = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary" # 규정 정책 고정
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "EKS 클러스터 Endpoint에 접근을 허용할 승인된 공인 IP 대역 리스트"
  nullable    = false
}

variable "eks_cluster_admin_principals" {
  description = "EKS 클러스터 관리자 접근(kubectl)을 부여할 IAM 유저 ARN 목록(팀원). D35"
  type        = list(string)
  default = [
    "arn:aws:iam::495599735720:user/team1-ykh",
    "arn:aws:iam::495599735720:user/team1-ssm",
    "arn:aws:iam::495599735720:user/team1-lhc",
    "arn:aws:iam::495599735720:user/team1-kwy",
    "arn:aws:iam::495599735720:user/team1-cjc",
  ]
}
