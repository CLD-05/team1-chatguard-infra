# envs/prod/infra/bastion.tf

# =========================================================================
# 1. Bastion 호스트용 최신 Amazon Linux 2023 AMI(이미지) ID 조회
# =========================================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "description"
    values = ["Amazon Linux 2023 AMI *"]
  }
}

# =========================================================================
# 2. 🔒 보안 하드닝: Ingress가 100% 차단된 무결성 Bastion 보안 그룹 (SG)
# =========================================================================
resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Prod Bastion Host Security Group (No Ingress, SSM Only Best Practice)"
  vpc_id      = module.network.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${local.name_prefix}-bastion-sg" }
}

# =========================================================================
# 3. 🔑 SSM 원격 제어 통신을 위한 운영계 IAM 역할 및 프로필 선언
# =========================================================================
resource "aws_iam_role" "bastion_ssm" {
  name = "${local.name_prefix}-bastion-ssm-role"

  permissions_boundary = var.iam_role_permissions_boundary

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# AWS 가 관리하는 SSM 핵심 에이전트 정책 연결
resource "aws_iam_role_policy_attachment" "bastion_ssm_attach" {
  role       = aws_iam_role.bastion_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 인스턴스에 IAM 옷을 입혀주기 위한 프로필 생성
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${local.name_prefix}-bastion-instance-profile"
  role = aws_iam_role.bastion_ssm.name
}

# =========================================================================
# 4. Bastion EC2 인스턴스 생성 (운영계 퍼블릭 서브넷 레이어 배치)
# =========================================================================
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  subnet_id = module.network.public_subnet_ids[0]

  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = { Name = "${local.name_prefix}-bastion-host" }
}
