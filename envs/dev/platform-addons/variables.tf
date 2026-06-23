variable "env" {
  type        = string
  description = "환경 구분 (dev 또는 prod)"
  default     = "dev"
}

# ---- Phase 0 애드온 Helm 차트 버전(고정, CLAUDE.md §3) ----

variable "keda_chart_version" {
  type        = string
  description = "KEDA Helm 차트 버전(큐 깊이 기반 워커 오토스케일)"
}

variable "external_secrets_chart_version" {
  type        = string
  description = "External Secrets Operator(ESO) Helm 차트 버전"
}

variable "aws_lbc_chart_version" {
  type        = string
  description = "AWS Load Balancer Controller(LBC) Helm 차트 버전 — iam/lbc-policy.json 버전과 정합"
}

variable "redis_exporter_chart_version" {
  type        = string
  description = "Prometheus Redis Exporter Helm 차트 버전"
}

variable "permissions_boundary_arn" {
  type        = string
  description = "학생 생성 IAM role 필수 권한 경계(CLAUDE.md §1-7, 없으면 apply 거부)"
  default     = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"
}
