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
}

# =========================================================================
# 2. 🔒 보안 하드닝: 22번 포트가 완전히 닫힌 Bastion 전용 보안 그룹 (SG)
# =========================================================================
resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Bastion Host Security Group (No Ingress 22, SSM Only)"
  vpc_id      = module.network.vpc_id # 1주차 네트워크 모듈의 VPC ID 참조

  # 인바운드(들어오는 문)를 완전히 비워둡니다. (SSM 대리인이 안에서 밖으로 터널을 뚫기 때문)

  # 아웃바운드(나가는 문): 내부망 및 패키지 업데이트를 위해 전체 허용
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
# 3. 🔑 SSM 원격 제어 통신을 위한 IAM 역할(Role) 및 프로필 정의
# =========================================================================
resource "aws_iam_role" "bastion_ssm" {
  name = "${local.name_prefix}-bastion-ssm-role"

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

# AWS가 관리하는 SSM 핵심 정책을 역할에 바인딩
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
# 4. Bastion EC2 인스턴스 생성 (Public 서브넷에 배치)
# =========================================================================
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro" # dev 환경이므로 가장 가성비 좋은 micro 스펙 적용

  # 💡 중요: 유저가 디딤돌로 밟고 들어와야 하므로 Public 서브넷 첫 번째 방에 배치합니다.
  subnet_id = module.network.public_subnet_ids[0]

  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  # 실무 하드닝: 루트 볼륨 암호화 및 gp3 스토리지 규격 적용
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${local.name_prefix}-bastion-host" }
}
