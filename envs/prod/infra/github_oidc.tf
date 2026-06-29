# envs/prod/infra/github_oidc.tf
# GitHub Actions(app 레포) → ECR push용 OIDC role(prod). dev/infra/github_oidc.tf 복제.

module "github_oidc" {
  source = "../../../modules/github_oidc"

  name             = "team1-gha-app-prod-role"
  github_org       = "CLD-05"
  github_repo      = "team1-chatguard-app"
  allowed_branches = ["main"] # 모듈은 branch sub만 지원(repo:.../ref:refs/heads/<b>). prod 전용 ref가 필요해지면 조정.

  # prod ECR repo(api-server·ai-worker·frontend) ARN으로 push 범위 제한.
  ecr_repository_arns = values(module.ecr.repository_arns)

  # prod 루트 관례: boundary는 변수로(bastion·eks와 동일). CLAUDE §1-7.
  permissions_boundary_arn = var.iam_role_permissions_boundary

  # create_oidc_provider = false  # 기본값. 계정당 1개뿐인 token.actions... provider를 data로 재사용(중복 생성 금지).
}

output "gha_app_prod_role_arn" {
  description = "deploy.yml(prod)의 AWS_ROLE_ARN에 넣을 값"
  value       = module.github_oidc.role_arn
}
