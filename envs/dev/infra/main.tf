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

  # 의존성 체이닝: EKS가 생성한 노드 보안 그룹을 받아 방화벽에 주입
  eks_node_security_group_id = module.eks.node_security_group_id

  instance_class = "db.t4g.micro"
}

# 고속 세션 및 pub/sub용 캐시 서버 배치
module "elasticache" {
  source              = "../../../modules/elasticache"
  cache_name          = "${local.name_prefix}-redis"
  vpc_id              = module.network.vpc_id
  isolated_subnet_ids = module.network.isolated_subnet_ids

  # 의존성 체이닝: 역시 EKS 노드 그룹만 접근 가능하도록 락킹
  eks_node_security_group_id = module.eks.node_security_group_id

  node_type = "cache.t4g.micro"
}
