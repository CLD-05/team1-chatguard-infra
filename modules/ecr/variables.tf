variable "repository_names" {
  description = "생성할 ECR 리포지토리 이름 리스트 (API 서버, 워커 등)"
  type        = list(string)
}

variable "force_delete" {
  description = "이미지가 남아 있어도 강제 삭제 허용 여부. prod는 false, dev destroy 시 true."
  type        = bool
  default     = false
}
