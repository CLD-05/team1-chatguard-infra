terraform {
  backend "s3" {
    bucket       = "tfstate-lionkdt5-team1"
    key          = "prod/platform-addons/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
