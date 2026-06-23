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

output "cluster_managed_security_group_id" {
  description = "EKS Cluster가 자체적으로 생성 및 관리하는 기본 보안 그룹 ID"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL — IRSA용 OIDC provider 생성에 사용(애드온 SA↔IAM role)"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
