# envs/dev/infra/oidc.tf
# EKS IRSA(ServiceAccount → IAM Role)를 가능하게 하는 OIDC provider.
# eks 모듈이 노출한 issuer URL로 생성 → platform-addons의 LBC·ESO IRSA role이 이 provider를 신뢰한다.
# 모듈 본체는 건드리지 않고 dev 레이어에서만 생성(블라스트 반경 최소화). prod는 후속에 동일 패턴으로 추가.

data "tls_certificate" "eks_oidc" {
  url = module.eks.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = { Name = "${local.name_prefix}-eks-oidc" }
}
