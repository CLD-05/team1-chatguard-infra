output "zone_id" {
  description = "Route53 호스팅 존의 고유 ID"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "도메인 구매처(가비아 등) 네임서버에 등록해야 할 AWS 고유 네임서버 4개"
  value       = aws_route53_zone.this.name_servers
}
