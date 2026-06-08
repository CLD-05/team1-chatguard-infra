output "redis_endpoint" {
  description = "채팅 서버 및 워커가 연결할 Redis 기본 엔드포인트 주소"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}
