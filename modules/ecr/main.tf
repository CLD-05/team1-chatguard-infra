# =========================================================================
# 1. ECR 리포지토리 생성 (리스트 변수를 받아 반복문으로 다중 생성)
# =========================================================================
resource "aws_ecr_repository" "this" {
  for_each             = toset(var.repository_names)
  name                 = each.value
  image_tag_mutability = "MUTABLE" # dev 환경이므로 같은 태그(latest 등)로 덮어쓰기 허용

  # 🔒 보안 하드닝: 이미지 푸시 시 자동으로 보안 취약점 스캔 실행
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256" # 저장 데이터 암호화 적용
  }

  tags = { Name = each.value }
}

# =========================================================================
# 2. 비용 방어를 위한 라이프사이클 정책 (Lifecycle Policy)
# =========================================================================
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  # 🔒 FinOps 비용 하드닝: 무기한 쌓이는 도ker 이미지 중 오래된 것은 30개만 남기고 자동 삭제
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images to prevent infinite storage cost"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
