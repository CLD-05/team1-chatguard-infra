# envs/prod/infra/providers.tf

terraform {
  required_version = ">= 1.14.0, < 1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "final-prod" # 운영 격리용 AWS CLI 프로파일 강제 지정 (실수 배포 방지)

  default_tags {
    tags = {
      Team        = "team1"
      Environment = "prod"
      Project     = "chatguard"
      Owner       = "infra-lead"
    }
  }
}
