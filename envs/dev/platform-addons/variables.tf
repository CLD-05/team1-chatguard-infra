variable "env" {
  type        = string
  description = "환경 구분 (dev 또는 prod)"
  default     = element(split("/", replace(path.cwd, "\\", "/")), length(split("/", replace(path.cwd, "\\", "/"))) - 2)
}
