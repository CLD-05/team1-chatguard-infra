output "bucket_name" {
  description = "생성된 S3 버킷 명"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "S3 버킷의 고유 ARN (IAM 정책 연동용)"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "S3 버킷의 도메인 웹 주소 URL"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
