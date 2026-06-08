terraform {
  required_version = ">= 1.14.0, < 1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "final"
}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "tfstate-lionkdt5-team1"
    key    = "team1/dev/infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# =========================================================================
# Kubernetes 공급자 설정
# =========================================================================
provider "kubernetes" {
  host                   = try(data.aws_eks_cluster.this.endpoint, "")
  cluster_ca_certificate = base64decode(try(data.aws_eks_cluster.this.certificate_authority[0].data, ""))
  token                  = try(data.aws_eks_cluster_auth.this.token, "")
}

# =========================================================================
# Helm 공급자 설정 
# =========================================================================
provider "helm" {
  kubernetes {
    host                   = try(data.aws_eks_cluster.this.endpoint, "")
    cluster_ca_certificate = base64decode(try(data.aws_eks_cluster.this.certificate_authority[0].data, ""))
    token                  = try(data.aws_eks_cluster_auth.this.token, "")
  }
} 
