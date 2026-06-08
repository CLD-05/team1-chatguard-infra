terraform {
  backend "s3" {
    bucket       = "tfstate-my-personal-sandbox"
    key          = "team1/dev/platform-addons/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
