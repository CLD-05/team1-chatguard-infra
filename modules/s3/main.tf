# =========================================================================
# 1. 서비스용 오리지널 S3 버킷 생성
# =========================================================================
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = true # dev 환경이므로 안에 파일이 있어도 테라폼 destroy 시 강제 삭제 허용

  tags = { Name = var.bucket_name }
}

# =========================================================================
# 2. 🔒 보안 하드닝: 퍼블릭 액세스 원천 차단 (Block Public Access)
# =========================================================================
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =========================================================================
# 3. 🔒 보안 하드닝: 저장 데이터 암호화 강제 (SSE-S3 기본 활성화)
# =========================================================================
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# =========================================================================
# 4. 실무 필수: 크로스 도메인 차단 해제 (CORS 규칙 설정)
# =========================================================================
# 프론트엔드 웹 브라우저에서 S3 URL로 직접 이미지를 업로드/다운로드할 수 있도록 문을 열어줍니다.
resource "aws_s3_bucket_cors_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"] # ⚠️prod 환경에서는 팀의 도메인 주소로 한정해야 합니다.
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
