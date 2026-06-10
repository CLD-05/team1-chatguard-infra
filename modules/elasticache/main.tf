# =========================================================================
# 1. Redis 전용 보안 그룹 (Security Group) 방화벽 설정
# =========================================================================
resource "aws_security_group" "redis" {
  name        = "${var.cache_name}-sg"
  description = "Allow Redis traffic only from EKS Worker Nodes"
  vpc_id      = var.vpc_id

  # 🔒 하드닝: 오직 우리 EKS 노드 그룹만 Redis 기본 포트(6379)로 진입 허용
  dynamic "ingress" {
    for_each = var.allowed_security_groups
    content {
      description     = "Redis from Allowed Security Groups"
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cache_name}-sg" }
}

# =========================================================================
# 2. Redis 가용영역 분산을 위한 서브넷 그룹 지정 (Isolated A, C 묶음)
# =========================================================================
resource "aws_elasticache_subnet_group" "this" {
  name        = "${var.cache_name}-subnet-group"
  subnet_ids  = var.isolated_subnet_ids
  description = "Redis Subnet Group in Isolated Zone"
}

# =========================================================================
# 3. ElastiCache Redis 클러스터 본체 생성
# =========================================================================
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.cache_name
  description          = "Redis cluster for ChatGuard session and pub/sub"

  engine             = "redis"
  engine_version     = "7.1"
  node_type          = var.node_type
  num_cache_clusters = 1 # dev 비용 최적화: 1개 노드로 구성 (prod는 2개 이상 확장)

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  port                       = 6379
  parameter_group_name       = "default.redis7"
  auto_minor_version_upgrade = true

  tags = { Name = var.cache_name }
}
