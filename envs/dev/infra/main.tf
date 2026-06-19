# envs/dev/infra/main.tf

locals {
  name_prefix = "team1-dev"
}

# 네트워크 인프라 대지 조성
module "network" {
  source      = "../../../modules/network"
  vpc_cidr    = var.vpc_cidr
  vpc_name    = "${local.name_prefix}-vpc"
  environment = var.env
}

# 쿠버네티스 컴퓨팅 기지 구축
module "eks" {
  source       = "../../../modules/eks"
  cluster_name = "${local.name_prefix}-cluster"
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids

  iam_role_permissions_boundary = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"
  public_access_cidrs           = var.eks_public_access_cidrs

  cluster_admin_principals = var.eks_cluster_admin_principals
}

# 완전 격리망 보안 데이터베이스 안착
module "database" {
  source              = "../../../modules/database"
  db_name             = "${local.name_prefix}-db"
  vpc_id              = module.network.vpc_id
  isolated_subnet_ids = module.network.isolated_subnet_ids

  # 모듈이 "dev" 임을 인지할 수 있도록 패스
  environment = var.env

  allowed_security_groups = [
    module.eks.cluster_managed_security_group_id,
    aws_security_group.bastion.id
  ]

  instance_class = "db.t4g.micro"
}

# 고속 세션 및 pub/sub용 캐시 서버 배치
module "elasticache" {
  source              = "../../../modules/elasticache"
  cache_name          = "${local.name_prefix}-redis"
  vpc_id              = module.network.vpc_id
  isolated_subnet_ids = module.network.isolated_subnet_ids

  allowed_security_groups = [
    module.eks.cluster_managed_security_group_id,
    aws_security_group.bastion.id
  ]

  node_type = "cache.t4g.micro"
}

# AWS Secrets Manager 내용물 자동 주입 설정
data "aws_secretsmanager_secret_version" "rds_generated_secret" {
  secret_id = module.database.rds_master_user_secret_arn
}

resource "aws_secretsmanager_secret_version" "chatguard_secret_content" {
  secret_id = aws_secretsmanager_secret.chatguard_secrets.id

  secret_string = jsonencode(
    merge(
      jsondecode(data.aws_secretsmanager_secret_version.rds_generated_secret.secret_string),
      {
        REDIS_HOST = module.elasticache.redis_endpoint
        REDIS_PORT = module.elasticache.redis_port
        DB_URL     = "jdbc:mysql://${module.database.db_endpoint}/${var.db_name}?useSSL=false&allowPublicKeyRetrieval=true"
      }
    )
  )
}

# 도커 컴포넌트 저장 기지 (ECR) 조립
module "ecr" {
  source = "../../../modules/ecr"
  repository_names = [
    "${local.name_prefix}-api-server", # 백엔드 Spring API 서버용 저장소
    "${local.name_prefix}-ai-worker",  # AI 모더레이션 Python 워커용 저장소
    "${local.name_prefix}-frontend"    # React 프론트엔드(nginx 서빙)용 저장소
  ]
}

# 애플리케이션 유저 파일 업로드용 S3 스토리지 조립
module "s3" {
  source      = "../../../modules/s3"
  bucket_name = "${local.name_prefix}-chatguard-assets"
}

# 대외 서비스 창구 도메인(Route53) 호스팅 존 조립
module "route53" {
  source      = "../../../modules/route53"
  domain_name = "chatguard.store" # 👈 팀의 실제 도메인 주소(또는 임시 주소)로 세팅
}
