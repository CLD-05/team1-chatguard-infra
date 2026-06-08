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

variable "desired_size" {
  description = "EKS 가동 시 유지할 기본 노드 개수"
  type        = number
  default     = 2
}
