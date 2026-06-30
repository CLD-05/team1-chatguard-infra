# modules/network/main.tf
# D54: AZ·NAT 변수화. availability_zones(명시 리스트)·single_nat_gateway 토글로
#   dev(2AZ·단일 NAT, 비용) / prod(3AZ·AZ별 NAT, HA·FIS AZ장애 데모 전제)를 한 모듈로 표현.
# 서브넷(3 tier)·EIP·NAT·private RT는 count로 AZ 수만큼 생성.
# public RT(→IGW)·isolated RT(무라우트)는 AZ 무관이라 단일 유지 — NAT만 AZ 의존.

locals {
  az_count  = length(var.availability_zones)
  nat_count = var.single_nat_gateway ? 1 : local.az_count
}

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

# Public 서브넷 (ALB, Bastion용) — AZ당 1개. CIDR idx = 0 .. az_count-1
resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags                    = merge({ Name = "${var.vpc_name}-public-${count.index}" }, var.public_subnet_extra_tags)
}

# Private 서브넷 (EKS 워커 노드용) — CIDR idx = az_count .. 2*az_count-1
resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, local.az_count + count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name                              = "${var.vpc_name}-private-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Isolated 서브넷 (RDS, ElastiCache 격리용) — CIDR idx = 2*az_count .. 3*az_count-1
resource "aws_subnet" "isolated" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 2 * local.az_count + count.index)
  availability_zone = var.availability_zones[count.index]
  tags              = { Name = "${var.vpc_name}-isolated-${count.index}" }
}

# NAT용 EIP — single_nat=true면 1개, 아니면 AZ당 1개
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = { Name = "${var.vpc_name}-nat-eip-${count.index}" }
}

# NAT 게이트웨이 — 각 NAT를 자기 인덱스의 public 서브넷(=자기 AZ)에 배치 → AZ별 egress
resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${var.vpc_name}-nat-gw-${count.index}" }
  depends_on    = [aws_internet_gateway.this]
}

# Public Route Table (→IGW) — AZ 무관, 단일
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.vpc_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table — single_nat이면 1개, 아니면 AZ당 1개(각 RT가 자기 AZ NAT를 지목).
# ★다중화 핵심: NAT가 여러 개여도 RT가 단일이면 트래픽이 한 NAT로 몰려 무의미 → RT도 AZ별로 가른다.
resource "aws_route_table" "private" {
  count  = local.nat_count
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = { Name = "${var.vpc_name}-private-rt-${count.index}" }
}

# Private 서브넷 ↔ RT 연결: single_nat이면 전부 RT[0], 아니면 자기 AZ의 RT[index]
resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Isolated Route Table (인터넷 라우트 없음, 완전 격리) — AZ 무관, 단일
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-isolated-rt" }
}

resource "aws_route_table_association" "isolated" {
  count          = local.az_count
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}
