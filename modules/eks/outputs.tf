output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API 서버 엔드포인트 URL"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Kubernetes API 서버 인증용 CA 데이터"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_security_group_id" {
  description = "EKS Node Group 클러스터 관리형 노드 보안 그룹 ID"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
