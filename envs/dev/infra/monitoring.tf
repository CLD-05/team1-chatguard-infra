# envs/dev/infra/monitoring.tf

data "terraform_remote_state" "infra_base" {
  backend = "s3"
  config = {
    bucket = "tfstate-lionkdt5-team1"
    key    = "team1/dev/infra-base/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# AWS 챗봇 슬랙 중계기 개설
module "observability_cloudwatch" {
  source                   = "../../../modules/observability-cloudwatch"
  db_instance_id           = module.database.db_instance_id
  slack_workspace_id       = var.slack_workspace_id
  slack_channel_id         = var.slack_channel_id
  env                      = var.env
  slack_webhook_secret_arn = data.terraform_remote_state.infra_base.outputs.slack_webhook_secret_arn
}
