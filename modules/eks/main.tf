# =========================================================================
# 1. EKS Control Plane (마스터) IAM Role
# =========================================================================
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-role"

  permissions_boundary = var.iam_role_permissions_boundary

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# =========================================================================
# 2. EKS 클러스터 본체 생성
# =========================================================================
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.35"

  # 접근 관리를 access entry(API) 방식으로 전환.
  # CONFIG_MAP → API_AND_CONFIG_MAP 은 안전한 단방향 전환(기존 aws-auth 권한 유지).
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true # 로컬 PC에서 kubectl 제어를 위해 일단 허용

    public_access_cidrs = var.public_access_cidrs
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]
}

# =========================================================================
# 3. EKS Worker Node (컴퓨팅) IAM Role
# =========================================================================
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  permissions_boundary = var.iam_role_permissions_boundary

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# =========================================================================
# 4-0. 노드 인스턴스/볼륨 태깅용 최소 Launch Template
# =========================================================================
# provider default_tags는 노드그룹 리소스엔 붙지만 ASG-런치 EC2 인스턴스엔 전파되지 않음 →
# tag_specifications로 인스턴스·EBS 볼륨에 직접 주입(Team 태그 부재 시 DenyOtherTeamResources로 자체 조작 차단).
# 인스턴스타입·AMI·SG·IAM은 넣지 않음 → 노드그룹의 instance_types/ami_type 및 EKS 자동 cluster SG를 그대로 유지.
resource "aws_launch_template" "node" {
  count       = length(var.node_instance_tags) > 0 ? 1 : 0
  name_prefix = "${var.cluster_name}-ng-"

  tag_specifications {
    resource_type = "instance"
    tags          = var.node_instance_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = var.node_instance_tags
  }
}

# =========================================================================
# 4. EKS 관리형 노드 그룹 생성 (t3.medium 사양 조립)
# =========================================================================
resource "aws_eks_node_group" "this" {
  cluster_name = aws_eks_cluster.this.name
  # node_group_name_prefix: 무중단 blue/green(create_before_destroy) 시 구 NG와 이름 충돌 없이 유니크 접미사 생성.
  # 고정 node_group_name + create_before_destroy는 CreateNodegroup 이름충돌로 실패하므로 prefix 방식 채택.
  node_group_name_prefix = "${var.cluster_name}-ng-"
  node_role_arn          = aws_iam_role.node.arn
  subnet_ids             = var.subnet_ids

  ami_type       = var.ami_type # D53: null=AWS 기본(x86), arm은 AL2023_ARM_64_STANDARD. instance_types와 동반 필수(ForceNew).
  instance_types = var.instance_types

  scaling_config {
    desired_size = var.desired_size
    max_size     = coalesce(var.max_size, var.desired_size + 2) # 미지정 시 기존 여유분(+2) 유지
    min_size     = coalesce(var.min_size, var.desired_size)
  }

  update_config {
    max_unavailable = 1
  }

  # node_instance_tags 지정 시에만 커스텀 LT 부착 → 인스턴스/볼륨 태깅. 미지정이면 EKS 자동 LT 유지.
  dynamic "launch_template" {
    for_each = length(var.node_instance_tags) > 0 ? [1] : []
    content {
      id      = aws_launch_template.node[0].id
      version = aws_launch_template.node[0].latest_version
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
  ]

  # 무중단 blue/green: 새 NG를 먼저 생성한 뒤 구 NG를 제거(노드 공백 최소화).
  lifecycle {
    create_before_destroy = true
  }
}

# =========================================================================
# 5. EKS Access Entry — 팀원 IAM 유저를 클러스터 접근자로 명시 등록
# =========================================================================
resource "aws_eks_access_entry" "admins" {
  for_each = toset(var.cluster_admin_principals)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(var.cluster_admin_principals)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}
