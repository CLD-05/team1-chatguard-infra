# envs/prod/platform-addons/variables.tf

variable "team" { type = string }
variable "argocd_chart_version" { type = string }
variable "prometheus_stack_version" { type = string }
variable "keda_chart_version" { type = string }

variable "external_secrets_chart_version" {
  type        = string
  description = "External Secrets Operator (ESO) Helm 차트 버전"
}

variable "aws_lbc_chart_version" {
  type        = string
  description = "AWS Load Balancer Controller (LBC) Helm 차트 버전"
}

variable "redis_exporter_chart_version" {
  type        = string
  description = "Prometheus Redis Exporter Helm 차트 버전"
}

variable "env" {
  type        = string
  description = "환경 구분 (dev 또는 prod)"
  default     = "prod"
}

variable "permissions_boundary_arn" {
  type        = string
  description = "학생 생성 IAM role 필수 권한 경계(CLAUDE.md §1-7, 없으면 apply 거부) — LBC·ESO IRSA role에 부착"
  default     = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"
}
