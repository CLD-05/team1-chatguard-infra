variable "cluster_name" {
  description = "EKS 클러스터 이름 (A부류 규칙: team1-dev-cluster 등)"
  type        = string
}

variable "vpc_id" {
  description = "EKS가 들어설 VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "EKS 워커 노드들이 배치될 Private 서브넷 ID 목록"
  type        = list(string)
}

variable "instance_types" {
  description = "워커 노드의 인스턴스 사양 (dev: ['t3.medium'])"
  type        = list(string)
  default     = ["t3.medium"]
}

# D53: 노드 AMI 타입. default null = AWS 기본(현행 x86) → 안 넘기는 환경 무영향.
# arm 노드는 "AL2023_ARM_64_STANDARD". ★ instance_types(arch)와 반드시 동반 — arm 인스턴스 + x86 AMI는 부팅 실패.
variable "ami_type" {
  description = "EKS 노드그룹 AMI 타입(예: AL2023_ARM_64_STANDARD). null이면 AWS 기본(x86)."
  type        = string
  default     = null
}

variable "desired_size" {
  description = "EKS 가동 시 유지할 기본 노드 개수"
  type        = number
  default     = 2
}

# min/max를 desired와 분리 지정할 때만 사용. null이면 기존 수식(min=desired, max=desired+2) 유지 → 안 넘기는 환경(dev) 무영향.
variable "min_size" {
  description = "노드그룹 최소 노드 수. null이면 desired_size와 동일(기존 동작)."
  type        = number
  default     = null
}

variable "max_size" {
  description = "노드그룹 최대 노드 수. null이면 desired_size + 2(기존 동작)."
  type        = number
  default     = null
}

variable "iam_role_permissions_boundary" {
  type        = string
  description = "AWS IAM Role 생성 제한을 위한 Permissions Boundary ARN"
  nullable    = false
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "EKS 클러스터 Public Endpoint에 접근 허용할 IP 대역 리스트"
  nullable    = false
}

variable "cluster_admin_principals" {
  description = "EKS 클러스터 관리자 접근을 부여할 IAM Principal ARN 목록(팀원 IAM 유저)."
  type        = list(string)
  default     = []
}
