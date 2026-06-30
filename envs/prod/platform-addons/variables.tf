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

variable "prometheus_adapter_chart_version" {
  type        = string
  description = "Prometheus Adapter (Custom Metrics API) Helm 차트 버전"
  default     = "4.11.0"
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

# H1: Grafana 어드민 비밀번호 — kubernetes_secret.grafana_admin(main.tf)의 admin-password 키로 들어감.
# 시크릿이라 default 없음(미주입 시 apply가 입력을 강제 → 빈 비밀번호 방지) + 코드/git 미커밋(CLAUDE §5).
# 주입: export TF_VAR_grafana_admin_password='<강한값>'  또는 gitignore된 terraform.tfvars.
variable "grafana_admin_password" {
  type        = string
  sensitive   = true
  description = "Grafana 어드민 비밀번호(평문 커밋 금지, apply 시 TF_VAR/tfvars로 주입). CLAUDE §5."
}
