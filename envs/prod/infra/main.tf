# envs/prod/infra/main.tf

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.team}-${var.env}"
}

module "network" {
  source   = "../../../modules/network"
  vpc_cidr = var.vpc_cidr
  vpc_name = "${local.name_prefix}-vpc"

  public_subnet_extra_tags = { "kubernetes.io/role/elb" = "1" } # ALB(인터넷)용 서브넷 디스커버리 태그 — LBC가 public 서브넷 식별. D47
}

module "eks" {
  source         = "../../../modules/eks"
  cluster_name   = "${local.name_prefix}-cluster"
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.private_subnet_ids
  instance_types = var.eks_instance_types
  desired_size   = var.eks_desired_size

  # D53: arm 노드(m7g — m type, 부하테스트 정확도). tfvars eks_instance_types=m7g.large와 동반.
  ami_type = "AL2023_ARM_64_STANDARD"

  iam_role_permissions_boundary = var.iam_role_permissions_boundary

  public_access_cidrs = var.eks_public_access_cidrs

  cluster_admin_principals = var.eks_cluster_admin_principals # 팀원 IAM 유저 kubectl 접근(EKS access entry). D35
}

module "database" {
  source              = "../../../modules/database"
  db_name             = "${local.name_prefix}-db"
  vpc_id              = module.network.vpc_id
  isolated_subnet_ids = module.network.isolated_subnet_ids

  allowed_security_groups = [
    module.eks.cluster_managed_security_group_id,
    aws_security_group.bastion.id
  ]

  instance_class = var.rds_instance_class

  # D54-a(현 단계): prod 미가동·매일 destroy → 삭제 가능·최종 스냅샷 미생성. backup/multi_az는 운영성/HA 테스트로 유지.
  # 보존 전환(prod 실가동·장기테스트) 시: deletion_protection=true + skip_final_snapshot=false + 유니크 final_snapshot_identifier 주입.
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
  multi_az                = true
}

module "elasticache" {
  source              = "../../../modules/elasticache"
  cache_name          = "${local.name_prefix}-redis"
  vpc_id              = module.network.vpc_id
  isolated_subnet_ids = module.network.isolated_subnet_ids

  allowed_security_groups = [
    module.eks.cluster_managed_security_group_id,
    aws_security_group.bastion.id
  ]

  node_type = var.redis_node_type

  # D54-a: prod Redis HA — 2노드 + 자동 failover + Multi-AZ(현행 isolated 2 AZ로 충족). dev는 미주입(default 단일).
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
}

# 운영계 AWS Secrets Manager 내용물 자동 주입 설정
resource "aws_secretsmanager_secret_version" "chatguard_prod_secret_content" {
  secret_id = aws_secretsmanager_secret.redis_secret.id

  secret_string = jsonencode({
    REDIS_HOST = module.elasticache.redis_endpoint
    REDIS_PORT = module.elasticache.redis_port
  })
}


module "ecr" {
  source = "../../../modules/ecr"
  repository_names = [
    "${local.name_prefix}-api-server",
    "${local.name_prefix}-ai-worker",
    "${local.name_prefix}-frontend" # D36: app·config와 글자 단위 일치(3개 repo 계약)
  ]
}

module "s3_images" {
  source      = "../../../modules/s3"
  bucket_name = "${local.name_prefix}-images" # 채팅 이미지 및 영구 미디어 적재용 버킷
}

module "s3_frontend" {
  source      = "../../../modules/s3"
  bucket_name = "${local.name_prefix}-frontend" # 프론트엔드 정적 파일 배포용 버킷
}

# 금칙어 시딩 및 데이터 마이그레이션 전용 완전 격리형 Private S3 버킷 (D51)
# banned_words.txt는 수동 주입(git 미커밋). chat-server IRSA(iam.tf)가 read.
resource "aws_s3_bucket" "banned_words_bucket" {
  bucket        = "${local.name_prefix}-chatguard-migration"
  force_destroy = true # prod 매일 destroy → 비어있지 않아도 삭제 허용(시드 파일은 apply 후 재주입)

  tags = {
    Name        = "${local.name_prefix}-chatguard-migration"
    Environment = "prod"
    Component   = "backend"
  }
}

# 금칙어 파일 이력 추적을 위한 버전 관리 활성화
resource "aws_s3_bucket_versioning" "banned_words_versioning" {
  bucket = aws_s3_bucket.banned_words_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

module "route53" {
  source      = "../../../modules/route53"
  domain_name = var.domain_name
}

# =========================================================================
# 운영계 ArgoCD용 IAM 역할 EKS RBAC 매핑
# =========================================================================
resource "aws_eks_access_entry" "argocd_admin_mapping" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/team1-prod-eks-admin-role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "argocd_admin_rbac" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.argocd_admin_mapping.principal_arn

  access_scope {
    type = "cluster"
  }
}
