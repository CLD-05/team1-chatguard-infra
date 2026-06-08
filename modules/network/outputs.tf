output "vpc_id" {
  description = "생성된 VPC의 ID 정보"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "ALB와 Bastion이 사용할 Public 서브넷 ID 리스트"
  value       = [aws_subnet.public_a.id, aws_subnet.public_c.id]
}

output "private_subnet_ids" {
  description = "EKS 클러스터 워커 노드가 위치할 Private 서브넷 ID 리스트"
  value       = [aws_subnet.private_a.id, aws_subnet.private_c.id]
}

output "isolated_subnet_ids" {
  description = "RDS MySQL 및 ElastiCache Redis가 격리되어 들어갈 Isolated 서브넷 ID 리스트"
  value       = [aws_subnet.isolated_a.id, aws_subnet.isolated_c.id]
}
