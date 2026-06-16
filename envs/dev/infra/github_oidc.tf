# envs/dev/infra/github_oidc.tf
# GitHub Actions(app 레포) → ECR push용 OIDC role.

# ECR repo ARN 조회. name_prefix local(main.tf)을 재사용해 생성 이름과 동기화.
data "aws_ecr_repository" "api_server" {
  name = "${local.name_prefix}-api-server"
}

data "aws_ecr_repository" "ai_worker" {
  name = "${local.name_prefix}-ai-worker"
}

data "aws_ecr_repository" "frontend" {
  name = "${local.name_prefix}-frontend"
}

module "github_oidc" {
  source = "../../../modules/github_oidc"

  name             = "team1-gha-app-dev-role"
  github_org       = "CLD-05"
  github_repo      = "team1-chatguard-app"
  allowed_branches = ["main"]

  ecr_repository_arns = [
    data.aws_ecr_repository.api_server.arn,
    data.aws_ecr_repository.ai_worker.arn,
    data.aws_ecr_repository.frontend.arn,
  ]

  # dev 컨벤션: ARN 직접 문자열(EKS·bastion과 동일). dev 루트엔 boundary 변수 없음.
  permissions_boundary_arn = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"

  # create_oidc_provider = false  # 기본값. 기존 token.actions... provider를 data로 참조
}

output "gha_app_dev_role_arn" {
  description = "deploy.yml의 AWS_ROLE_ARN에 넣을 값"
  value       = module.github_oidc.role_arn
}
