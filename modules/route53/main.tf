# =========================================================================
# 1. 대외 도메인 관리를 위한 Route53 Public Hosted Zone 생성
# =========================================================================
resource "aws_route53_zone" "this" {
  name          = var.domain_name
  force_destroy = false # 도메인 네임서버 정보는 중요하므로 실수로 삭제되지 않게 보호

  tags = { Name = var.domain_name }
}
