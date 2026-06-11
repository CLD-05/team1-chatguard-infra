# envs/dev/infra/outputs.tf 

output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name # 기존 eks 모듈의 output 이름을 지정
}

output "eks_cluster_endpoint" {
  description = "EKS 클러스터 API 엔드포인트 주소"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "EKS 클러스터 CA 인증서 데이터"
  value       = module.eks.cluster_certificate_authority_data
}
