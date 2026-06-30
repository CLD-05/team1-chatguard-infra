# envs/dev/infra-base/providers.tf

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Team        = "team1"
      Environment = "dev"
      Project     = "chatguard"
      Owner       = "infra-lead"
    }
  }
}
