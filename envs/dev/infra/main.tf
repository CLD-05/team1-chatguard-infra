# envs/dev/infra/main.tf

locals {
  name_prefix = "team1-dev"
}

# VPC
module "network" {
  source      = "../../../modules/network"
  vpc_cidr    = "10.1.0.0/17"
  vpc_name    = "${local.name_prefix}-vpc"
  environment = "dev"
}

# EKS 클러스터
module "eks" {
  source       = "../../../modules/eks"
  cluster_name = "${local.name_prefix}-cluster" # team1-dev-cluster
  vpc_id       = module.network.vpc_id

  subnet_ids = module.network.private_subnet_ids

  instance_types = ["t3.medium"]
  desired_size   = 2
}
