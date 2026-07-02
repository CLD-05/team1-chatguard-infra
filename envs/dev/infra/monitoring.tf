# envs/dev/infra/monitoring.tf

# AWS 챗봇 슬랙 중계기 개설
module "observability_cloudwatch" {
  source             = "../../../modules/observability-cloudwatch"
  db_instance_id     = module.database.db_instance_id
  slack_workspace_id = var.slack_workspace_id
  slack_channel_id   = var.slack_channel_id
  env                = var.env
}
