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

  instance_types = ["t3.medium"]
  desired_size   = 2
}

# 완전 격리망 보안 데이터베이스 안착
module "database" {
  source              = "../../../modules/database"
  db_name             = "${local.name_prefix}-db"
  vpc_id              = module.network.vpc_id
  isolated_subnet_ids = module.network.isolated_subnet_ids

  allowed_security_groups = [
    module.eks.node_security_group_id, # 기존 EKS 노드 진입 허용
    aws_security_group.bastion.id      # [추가] Bastion 호스트의 진입도 추가 허용
  ]

  instance_class = "db.t4g.micro"
  # EKS 모듈이 완벽히 완공되어 SG ID가 확정될 때까지 DB 생성을 대기
  depends_on = [module.eks]
}

# 고속 세션 및 pub/sub용 캐시 서버 배치
module "elasticache" {
  source              = "../../../modules/elasticache"
  cache_name          = "${local.name_prefix}-redis"
  vpc_id              = module.network.vpc_id
  isolated_subnet_ids = module.network.isolated_subnet_ids

  allowed_security_groups = [
    module.eks.node_security_group_id, # 기존 EKS 노드 진입 허용
    aws_security_group.bastion.id      # [추가] Bastion 호스트의 진입도 추가 허용
  ]

  node_type = "cache.t4g.micro"
  # Redis도 EKS 모듈 완공 후에 진격하도록 락
  depends_on = [module.eks]
}

# 도커 컴포넌트 저장 기지 (ECR) 조립
module "ecr" {
  source = "../../../modules/ecr"
  repository_names = [
    "${local.name_prefix}-api-server", # 백엔드 Spring API 서버용 저장소
    "${local.name_prefix}-ai-worker"   # AI 모더레이션 Python 워커용 저장소
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
