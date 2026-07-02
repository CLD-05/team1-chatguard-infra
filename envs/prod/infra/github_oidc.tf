# envs/prod/infra/github_oidc.tf
# GitHub Actions(app 레포) → ECR push용 OIDC role(prod). dev/infra/github_oidc.tf 복제.

module "github_oidc" {
  source = "../../../modules/github_oidc"

  name        = "team1-gha-app-prod-role"
  github_org  = "CLD-05"
  github_repo = "team1-chatguard-app"

  # 승격 파이프라인(deploy.yml promote-prod/update-config-prod)은 production environment
  # 승인 게이트를 통과한 job만 이 role을 assume — sub를 branch ref 대신 environment로
  # 제한해 게이트를 AWS 인증 레벨에서 강제(§7). branch sub는 비활성(빈 목록).
  allowed_branches     = []
  allowed_environments = ["production"]

  # prod ECR repo(api-server·ai-worker·frontend) ARN으로 push 범위 제한.
  ecr_repository_arns = values(module.ecr.repository_arns)

  # crane copy 승격의 소스(dev ECR 3종) pull 최소권한. dev state output은 cross-state라
  # 참조하지 않고 리터럴로 구성(이름은 D36 계약으로 고정).
  ecr_pull_repository_arns = [
    "arn:aws:ecr:ap-northeast-2:495599735720:repository/team1-dev-api-server",
    "arn:aws:ecr:ap-northeast-2:495599735720:repository/team1-dev-ai-worker",
    "arn:aws:ecr:ap-northeast-2:495599735720:repository/team1-dev-frontend",
  ]

  # prod 루트 관례: boundary는 변수로(bastion·eks와 동일). CLAUDE §1-7.
  permissions_boundary_arn = var.iam_role_permissions_boundary

  # create_oidc_provider = false  # 기본값. 계정당 1개뿐인 token.actions... provider를 data로 재사용(중복 생성 금지).
}

output "gha_app_prod_role_arn" {
  description = "deploy.yml(prod)의 AWS_ROLE_ARN에 넣을 값"
  value       = module.github_oidc.role_arn
}
