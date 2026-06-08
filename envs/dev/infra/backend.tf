terraform {
  backend "s3" {
    bucket       = "tfstate-lionkdt5-team1"
    key          = "team1/dev/infra/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
