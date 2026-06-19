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
