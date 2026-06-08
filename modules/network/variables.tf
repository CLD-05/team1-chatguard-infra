variable "vpc_cidr" {
  description = "VPC에 할당할 메인 CIDR 블록"
  type        = string
}

variable "vpc_name" {
  description = "VPC 리소스의 Name 태그에 들어갈 이름 (B부류 규칙)"
  type        = string
}

variable "environment" {
  description = "환경 구분 (dev 또는 prod)"
  type        = string
}
