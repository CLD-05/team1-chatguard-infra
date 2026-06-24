# =========================================================================
# 1. RDS 전용 보안 그룹 (Security Group) 방화벽 설정
# =========================================================================
resource "aws_security_group" "db" {
  name        = "${var.db_name}-sg"
  description = "Allow MySQL traffic only from EKS Worker Nodes"
  vpc_id      = var.vpc_id

  # 🔒 하드닝: 오직 EKS 노드 그룹 보안 그룹을 가진 자원만 3306 포트로 진입 허용
  dynamic "ingress" {
    for_each = var.allowed_security_groups
    content {
      description     = "MySQL from Allowed Security Groups"
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  # 아웃바운드는 기본적으로 전부 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.db_name}-sg" }
}

# =========================================================================
# 2. RDS 가용영역 분산을 위한 서브넷 그룹 지정 (Isolated A, C 묶음)
# =========================================================================
resource "aws_db_subnet_group" "this" {
  name        = "${var.db_name}-subnet-group"
  subnet_ids  = var.isolated_subnet_ids
  description = "DB Subnet Group in Isolated Zone"

  tags = { Name = "${var.db_name}-subnet-group" }
}

# =========================================================================
# 3. RDS MySQL 인스턴스 본체 생성
# =========================================================================
resource "aws_db_instance" "this" {
  identifier            = var.db_name
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = var.instance_class
  allocated_storage     = 20
  max_allocated_storage = 100 # 스토리지 자동 오토스케일링 허용

  db_name  = "chatguard"
  username = "admin"

  manage_master_user_password = true
  password                    = null

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # main.tf 변수 매핑 유지
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  backup_retention_period = var.backup_retention_period
  multi_az                = var.multi_az

  tags = { Name = var.db_name }
}
