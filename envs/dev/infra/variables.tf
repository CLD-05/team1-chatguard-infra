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

variable "eks_cluster_admin_principals" {
  description = "EKS 클러스터 관리자 접근 IAM 유저 ARN 목록(팀원)."
  type        = list(string)
  default = [
    # team1-cjc(=클러스터 생성자/운전자, CLAUDE.md §5)는 bootstrap_cluster_creator_admin_permissions=true로
    # 자동 admin → 명시 등록 시 409 중복(D35 보강). 생성자가 바뀌면 이 전제 재검토.
    "arn:aws:iam::495599735720:user/team1-ykh",
    "arn:aws:iam::495599735720:user/team1-ssm",
    "arn:aws:iam::495599735720:user/team1-lhc",
    "arn:aws:iam::495599735720:user/team1-kwy",
  ]
}

variable "db_name" {
  type        = string
  description = "MySQL 데이터베이스 이름"
  default     = "chatguard"
}
