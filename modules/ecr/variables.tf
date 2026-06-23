variable "repository_names" {
  description = "생성할 ECR 리포지토리 이름 리스트 (API 서버, 워커 등)"
  type        = list(string)
}

variable "force_delete" {
  type    = bool
  default = false
}
