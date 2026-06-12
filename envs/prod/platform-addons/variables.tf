# envs/prod/platform-addons/variables.tf

variable "team" { type = string }
variable "env" { type = string }

variable "argocd_chart_version" { type = string }
variable "prometheus_stack_version" { type = string }
variable "keda_chart_version" { type = string }
