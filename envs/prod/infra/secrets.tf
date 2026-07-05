resource "aws_secretsmanager_secret" "redis_secret" {
  name                    = "team1-prod-redis-secrets"
  description             = "ChatGuard prod 환경 Redis 연결 정보 금고"
  recovery_window_in_days = 0 # prod 매일 destroy → 즉시 삭제 허용(복구창>0은 동일 이름 재생성 차단 → 다음날 apply가 "scheduled for deletion"으로 CreateSecret 실패). 값은 TF가 apply마다 자동 재주입(main.tf secret_version)이라 소실 무해. jwt/dev 금고와 동일 관례.
}

# =========================================================================
# JWT 서명 키 금고 — config 레포 prod ExternalSecret이 secret_key→JWT_SECRET으로 읽음.
# (prod ESO 계약: rds!db-…(DB자동) + team1-prod-jwt-credentials. DB_URL/REDIS는 ConfigMap 리터럴.)
# =========================================================================
resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "team1-prod-jwt-credentials"
  description             = "ChatGuard prod 환경 JWT 서명 키 금고(secret_key 수동 주입)"
  recovery_window_in_days = 0 # prod 매일 destroy → 즉시 삭제 허용(7일 복구창은 동일 이름 재생성 차단). dev redis/grafana 금고와 동일 관례.

  tags = {
    Name = "team1-prod-jwt-credentials"
  }

  # B-3: 컨테이너만 생성하고 값(secret_key)은 수동 주입(openssl rand -base64 32).
  #   - 매일 destroy + recovery_window=0 → 주입한 값이 destroy마다 소실 → apply 후 재주입 + chat-server/worker rollout.
  #   - 지금은 TF secret_version이 없어 덮어쓰기 위험 없음. 향후 이 금고에 자동 secret_version을 추가한다면
  #     반드시 lifecycle { ignore_changes = [secret_string] } 를 붙여 수동 주입 secret_key 클로버를 막을 것.
  #   - 근본해결(자동 주입/회전)은 후속(B-3 트래커).
}

# =========================================================================
# Alertmanager Slack Webhook 금고 — platform-addons의 ExternalSecret(monitoring ns)이
# 원문(raw string)을 읽어 k8s Secret으로 동기화 → Alertmanager가 파일 마운트로 참조(slack_api_url_file).
# §0-3 진단 후속: 룰은 발화하나 receiver 부재 → Slack 경로 신설(DESIGN D6/B-4).
#   - 이름은 team1-prod-* 필수: prod ESO role 가독 범위가 secret:team1-prod-* (platform-addons addons.tf).
#   - KMS는 관리키(alias/aws/secretsmanager) 고정: ESO kms:Decrypt가 그 키에 한정 → CMK 쓰면 복호화 실패.
# =========================================================================
resource "aws_secretsmanager_secret" "alertmanager_slack_webhook" {
  name                    = "team1-prod-alertmanager-slack-webhook"
  description             = "ChatGuard prod Alertmanager Slack Webhook URL 금고(값 수동 주입, raw string)"
  recovery_window_in_days = 0 # prod 매일 destroy → 즉시 삭제 허용(복구창>0은 동일 이름 재생성 차단). redis/jwt 금고와 동일 관례.

  tags = {
    Name = "team1-prod-alertmanager-slack-webhook"
  }

  # 컨테이너만 생성 — 값(Webhook URL 원문)은 수동 주입(CLAUDE §5: 시크릿 원문 코드·state 금지):
  #   aws secretsmanager put-secret-value --secret-id team1-prod-alertmanager-slack-webhook \
  #     --secret-string 'https://hooks.slack.com/services/…' --region ap-northeast-2 --profile final
  #   (JSON 아님 — ExternalSecret이 property 없이 SecretString 전체를 raw URL로 읽음)
  #   매일 destroy + recovery_window=0 → 값이 destroy마다 소실 → apply 후 재주입 필요(jwt와 동일).
  #   향후 이 금고에 TF secret_version을 추가한다면 반드시 lifecycle { ignore_changes = [secret_string] }.
}

# =========================================================================
# ArgoCD EKS 조작을 위한 관리자 IAM 역할 생성
# =========================================================================
resource "aws_iam_role" "eks_admin_role" {
  name                 = "team1-${var.env}-eks-admin-role"
  permissions_boundary = "arn:aws:iam::495599735720:policy/TeamRuntimeBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        # 향후 ArgoCD 전용 IRSA(OIDC)가 완벽히 구성되면 이 부분을 OIDC Provider ARN으로 교체하기 전까지 최소한의 통로만 열어둔다
      }
    ]
  })
}

# 역할에 실제 관리자 권한 매핑
resource "aws_iam_role_policy_attachment" "eks_admin_policy" {
  role       = aws_iam_role.eks_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
