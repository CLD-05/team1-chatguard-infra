# VPC 생성
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

# 인터넷 게이트웨이 (Public 서브넷 외부 통신용)
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-igw" }
}

# Public 서브넷 (ALB, Bastion용)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, 0) # 10.1.0.0/21
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags                    = merge({ Name = "${var.vpc_name}-public-2a" }, var.public_subnet_extra_tags)
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, 1) # 10.1.8.0/21
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags                    = merge({ Name = "${var.vpc_name}-public-2c" }, var.public_subnet_extra_tags)
}

# Private 서브넷 (EKS 워커 노드 가동용)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 2) # 10.1.16.0/21
  availability_zone = "ap-northeast-2a"
  tags = {
    Name                              = "${var.vpc_name}-private-2a"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 3) # 10.1.24.0/21
  availability_zone = "ap-northeast-2c"
  tags = {
    Name                              = "${var.vpc_name}-private-2c"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Isolated 서브넷 (RDS, ElastiCache 데이터 격리용)
resource "aws_subnet" "isolated_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 4) # 10.1.32.0/21
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "${var.vpc_name}-isolated-2a" }
}

resource "aws_subnet" "isolated_c" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 5) # 10.1.40.0/21
  availability_zone = "ap-northeast-2c"
  tags              = { Name = "${var.vpc_name}-isolated-2c" }
}

# NAT 게이트웨이 및 EIP 세팅 (Private 파드들이 아웃바운드로 인터넷 통신을 하기 위함)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.vpc_name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.vpc_name}-nat-gw" }
  depends_on    = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.vpc_name}-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table (NAT Gateway를 바라보게 설정)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = { Name = "${var.vpc_name}-private-rt" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

# Isolated Route Table (인터넷 통신 완전 차단, 내부 연결용)
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-isolated-rt" }
}

resource "aws_route_table_association" "isolated_a" {
  subnet_id      = aws_subnet.isolated_a.id
  route_table_id = aws_route_table.isolated.id
}

resource "aws_route_table_association" "isolated_c" {
  subnet_id      = aws_subnet.isolated_c.id
  route_table_id = aws_route_table.isolated.id
}
