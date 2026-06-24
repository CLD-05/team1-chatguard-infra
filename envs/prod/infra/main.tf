# envs/prod/infra/main.tf

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.team}-${var.env}"
}

module "network" {
  source      = "../../../modules/network"
  vpc_cidr    = var.vpc_cidr
  vpc_name    = "${local.name_prefix}-vpc"
  environment = var.env # "prod" 주입
}

module "eks" {
  source         = "../../../modules/eks"
  cluster_name   = "${local.name_prefix}-cluster"
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.private_subnet_ids
  instance_types = var.eks_instance_types
  desired_size   = var.eks_desired_size

  iam_role_permissions_boundary = var.iam_role_permissions_boundary

  public_access_cidrs = var.eks_public_access_cidrs
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

  # 운영계 전용 삭제 방지 및 고가용성 파라미터 명시적 강제 주입
  deletion_protection     = true
  skip_final_snapshot     = false
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
    "${local.name_prefix}-ai-worker"
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
