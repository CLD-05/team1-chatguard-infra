# envs/prod/infra/providers.tf

terraform {
  required_version = ">= 1.14.0, < 1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "final" # dev·prod 동일 계정(495599735720)·단일 프로필. 환경 격리는
  #   디렉터리(envs/)+state key로 처리(CLAUDE.md §3·§5).

  default_tags {
    tags = {
      Team        = "team1"
      Environment = "prod"
      Project     = "chatguard"
      Owner       = "infra-lead"
    }
  }
}
