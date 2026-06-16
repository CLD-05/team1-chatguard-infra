# modules/github_oidc/variables.tf

variable "name" {
  description = "IAM role 이름. deploy.yml의 AWS_ROLE_ARN과 일치해야 함."
  type        = string
  # 예: team1-gha-app-dev-role
}

variable "github_org" {
  description = "GitHub org/owner (repo sub의 앞부분)."
  type        = string
  # 예: CLD-05
}

variable "github_repo" {
  description = "AssumeRole을 허용할 repo 이름."
  type        = string
  # 예: team1-chatguard-app
}

variable "allowed_branches" {
  description = "role을 가져갈 수 있는 브랜치 목록. 기본 main 한정."
  type        = list(string)
  default     = ["main"]
}

variable "ecr_repository_arns" {
  description = "push 권한을 부여할 ECR repository ARN 목록(api-server·ai-worker·frontend)."
  type        = list(string)
}

variable "permissions_boundary_arn" {
  description = "필수. CLAUDE.md §1-7 — 모든 team1 IAM role에 TeamRuntimeBoundary 부착."
  type        = string
  # arn:aws:iam::495599735720:policy/TeamRuntimeBoundary
}

variable "create_oidc_provider" {
  description = "true=Provider 신규 생성 / false=계정에 이미 있는 것을 data로 참조. 공유 계정이라 기본 false 권장."
  type        = bool
  default     = false
}

variable "tags" {
  description = "표준 태그(default_tags로 대부분 부착되므로 보통 비움)."
  type        = map(string)
  default     = {}
}
