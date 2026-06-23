# envs/dev/infra/github_oidc.tf
# GitHub Actions(app 레포) → ECR push용 OIDC role.

module "github_oidc" {
  source = "../../../modules/github_oidc"

  name             = "team1-gha-app-dev-role"
  github_org       = "CLD-05"
  github_repo      = "team1-chatguard-app"
  allowed_branches = ["main"]

  # ECR ARN을 같은 루트 module.ecr의 output(resource 참조)으로 받는다 → data 선존재 요구 제거.
  # clean apply에서도 TF가 module.ecr → 이 role 순서를 자동 정렬(닭-달걀 해소).
  ecr_repository_arns = values(module.ecr.repository_arns)

  # dev 컨벤션: ARN 직접 문자열(EKS·bastion과 동일). dev 루트엔 boundary 변수 없음.
  permissions_boundary_arn = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"

  # create_oidc_provider = false  # 기본값. 기존 token.actions... provider를 data로 참조
}

output "gha_app_dev_role_arn" {
  description = "deploy.yml의 AWS_ROLE_ARN에 넣을 값"
  value       = module.github_oidc.role_arn
}
