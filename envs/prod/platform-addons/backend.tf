terraform {
  backend "s3" {
    bucket       = "team1-prod-tfstate"
    key          = "team1/prod/platform-addons/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
