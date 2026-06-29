# envs/dev/infra/main.tf

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "team1-dev"
}

# 네트워크 인프라 대지 조성
module "network" {
  source   = "../../../modules/network"
  vpc_cidr = var.vpc_cidr
  vpc_name = "${local.name_prefix}-vpc"

  public_subnet_extra_tags = { "kubernetes.io/role/elb" = "1" } # ALB(인터넷)용 서브넷 디스커버리 태그 — LBC가 public 서브넷 식별. D47
}

# 쿠버네티스 컴퓨팅 기지 구축
module "eks" {
  source       = "../../../modules/eks"
  cluster_name = "${local.name_prefix}-cluster"
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids

  # D53: arm 노드(t4g — t type 유지=비용·오토스케일 데모 유리). ami_type과 instance_types 동반 필수.
  instance_types = ["t4g.medium"]
  ami_type       = "AL2023_ARM_64_STANDARD"

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

# 도커 컴포넌트 저장 기지 (ECR) 조립
module "ecr" {
  source       = "../../../modules/ecr"
  force_delete = true

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

# 금칙어 시딩 및 데이터 마이그레이션 전용 완전 격리형 Private S3 버킷
resource "aws_s3_bucket" "banned_words_bucket" {
  bucket        = "${local.name_prefix}-chatguard-migration"
  force_destroy = true # 개발(dev) 환경의 빠른 피드백 및 파일 테스트 삭제를 위한 설정

  tags = {
    Name        = "${local.name_prefix}-chatguard-migration"
    Environment = "dev"
    Component   = "backend"
  }
}

# 금칙어 파일 이력 추적을 위한 버전 관리 활성화 (실무 권장)
resource "aws_s3_bucket_versioning" "banned_words_versioning" {
  bucket = aws_s3_bucket.banned_words_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 대외 서비스 창구 도메인(Route53) 호스팅 존 조립
module "route53" {
  source      = "../../../modules/route53"
  domain_name = "chatguard.store" # 👈 팀의 실제 도메인 주소(또는 임시 주소)로 세팅
}

# =========================================================================
# ArgoCD용 IAM 역할을 EKS 최고 권한(cluster-admin)과 RBAC 매핑
# =========================================================================
resource "aws_eks_access_entry" "argocd_admin_mapping" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/team1-dev-eks-admin-role"
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
