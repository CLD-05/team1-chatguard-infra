# team1-chatguard-infra

ChatGuard의 **Terraform IaC 전용** 레포 (`modules/` + `envs/dev`·`envs/prod`). 서울 리전(`ap-northeast-2`)·계정 `495599735720`·프로필 `final` 전용. AWS 인증은 OIDC(Access Key 금지).

> 설계·결정 기록의 **SSoT는 `../team1-chatguard-context`** (팀 규칙 `CLAUDE.md` · 설계 `DESIGN.md`). 이 레포 전용 규칙은 `./CLAUDE.md`. 본 README는 **dev 환경 apply/destroy 운영 절차**에 집중한다.
>
> ⚠️ dev state는 공유 → **apply/destroy는 한 명(운전자)이 수행**, 나머지는 PR로 기여. **destroy·prod 변경 전에는 반드시 사람 확인.**

## 구조

두 개의 **독립 Terraform 루트**(각자 `.terraform.lock.hcl`·state). apply는 **① infra → ② platform-addons** 순서 — EKS가 떠야 그 위 Helm 설치가 가능하다.

| 루트 | state key (S3 `tfstate-lionkdt5-team1`) | 만드는 것 |
|---|---|---|
| `envs/dev/infra` | `team1/dev/infra/terraform.tfstate` | VPC · EKS(+노드그룹) · RDS(MySQL) · ElastiCache(Redis) · ECR×3 · IRSA용 OIDC provider · IAM · Secrets Manager **금고(컨테이너)** |
| `envs/dev/platform-addons` | `team1/dev/platform-addons/terraform.tfstate` | Helm: ArgoCD · kube-prometheus-stack · KEDA · LBC · ESO · redis_exporter · prometheus-adapter + LBC/ESO IRSA role |

- 백엔드: S3 네이티브 락(`use_lockfile=true`, DynamoDB 미사용)·`encrypt=true`.
- 앱 Deployment/Service/Ingress·HPA·KEDA ScaledObject·ServiceMonitor·ExternalSecret 등은 **여기서 안 만든다** → config 레포(GitOps/ArgoCD) 소유 (CLAUDE.md §4).
- `modules/`는 검증본(공유). dev/prod는 **디렉터리**로 분리(브랜치 아님), 차이는 tfvars로만.

## 사전 준비

```bash
export AWS_PROFILE=final          # 계정 495599735720 · ap-northeast-2
aws sts get-caller-identity       # team1-* 유저인지 확인
```

각 루트에서 `terraform.tfvars` 준비(실물은 `.gitignore` 대상 — **커밋 금지**):

```bash
# infra — team / env / vpc_cidr
cd envs/dev/infra && cp terraform.tfvars.example terraform.tfvars
#   vpc_cidr=10.1.0.0/17  ← dev.  ⚠️ prod는 10.1.128.0/17 (혼동 금지)

# platform-addons — 차트 버전 고정값(필수 변수: keda/eso/lbc/redis_exporter)
cd ../platform-addons && cp terraform.tfvars.example terraform.tfvars
```

## Apply (dev — 2026-06-23 clean teardown에서 검증된 순서)

```bash
# ① infra
cd envs/dev/infra
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars      # EKS 생성 15~20분. 생성자=운전자는 bootstrap으로 자동 admin

# ② kubeconfig + 노드 확인
aws eks update-kubeconfig --name team1-dev-cluster --region ap-northeast-2 --profile final
kubectl get nodes                               # 전부 Ready 확인

# ③ ⭐ Grafana 시크릿 값 주입 — infra는 '빈 금고'만 만든다(§5: 진짜 비번은 사람이 주입).
#    이 단계를 빠뜨리면 ④ platform-addons plan이 '시크릿 버전 부재'로 깨진다.
#    dev는 destroy 시 금고가 소멸(recovery_window=0)하므로 매 apply 사이클마다 재실행(→ Known Issues 수동①).
aws secretsmanager put-secret-value \
  --secret-id team1-dev-grafana-credentials \
  --secret-string '{"password":"<DEV_GRAFANA_PW>"}' \
  --profile final --region ap-northeast-2        # JSON 키는 반드시 "password"

# ④ platform-addons
cd ../platform-addons
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
#   LBC webhook race로 1회 실패할 수 있음 → 아래로 LBC 파드 Running 확인 후 재apply하면
#   Terraform이 실패 릴리스를 정리하고 재생성한다(검증됨).
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

## 검증 (apply 후 토대 확인 — 검증된 명령)

```bash
kubectl get pods -n monitoring         # kube-prometheus-stack(+prometheus-adapter)·redis-exporter
kubectl get pods -n keda               # KEDA operator
kubectl get pods -n external-secrets   # ESO
kubectl get pods -n kube-system | grep aws-load-balancer-controller
kubectl get ingressclass               # 'alb'=LBC 준비 완료(토대, D47). 실제 ALB·외부 URL은 config가 Ingress를 배포해야 생성됨
#   → 이 단계(Phase 0)에선 `kubectl get ingress -A`가 비어있는 게 정상
kubectl get servicemonitor -A          # redis-exporter 등 스크레이프 대상
```

## Destroy (dev — apply 역순 · ⚠️ 사람 확인 필수)

> ⚠️ **이 destroy 순서는 소유 경계(CLAUDE.md §4)로 도출했으나 아직 미실행 검증이다** — 오늘(2026-06-23)은 apply만 검증됐고 destroy는 실행하지 않았다. 위 Apply 섹션의 "검증됨"과 구분할 것. **첫 destroy 시 단계별로 확인하며 진행**한다.
>
> **순서가 핵심.** ALB는 Terraform이 아니라 **LBC(파드)가 Ingress를 보고** 만든다(CLAUDE.md §4). LBC를 먼저 지우면 ALB가 **고아**로 남아 공유 계정·다른 팀에 피해(§1). → 클러스터 워크로드부터 회수하고, 컨트롤러는 나중에.

```bash
# ⓪ (config/app이 ArgoCD로 배포된 경우에만) Ingress부터 제거 — ALB 고아 방지(CLAUDE.md §4)
#    Phase 0만 올린 상태(앱 미배포)면 Ingress가 없으니 이 단계는 건너뛴다.
kubectl delete ingress --all -A                  # ALB 회수 (배포된 경우 필수)
#   ArgoCD Application으로 배포했다면 해당 app을 먼저 제거(재싱크로 되살아남 방지)
#   (LB 타입 Service(예: ArgoCD)는 platform-addons terraform destroy가 정리하므로 별도 삭제 불필요)

# ① platform-addons destroy (클러스터가 살아있는 동안 — provider가 클러스터에 접속)
cd envs/dev/platform-addons
terraform destroy -var-file=terraform.tfvars

# ② infra destroy (클러스터·VPC·RDS·Redis·ECR·시크릿 금고 제거)
cd ../infra
terraform destroy -var-file=terraform.tfvars
#   grafana 금고: recovery_window_in_days=0 → 즉시 삭제 → 다음 apply 때 ③ 재주입 필요
#   ECR: force_delete=true(dev)라 이미지가 있어도 삭제됨
```

## Known Issues & 후속

| # | 현상 | 임시 조치 | 후속 개선 |
|---|---|---|---|
| 수동① | grafana 시크릿을 매 apply 전 수동 주입(`recovery_window=0`이라 destroy 시 소멸) | Apply ③의 `put-secret-value` | ESO로 Secrets Manager 동기화(D34 최종형, config 소관) → plan이 시크릿 값에 의존하지 않게 되어 제거 |
| 수동② | platform-addons apply가 LBC webhook race로 1회 실패 가능 | LBC 파드 Running 확인 후 재apply | prometheus_stack 등에 LBC readiness 대기(`depends_on`) |
| 설계 | EKS access entry 409 — **운전자=클러스터 생성자**는 admin 목록에서 제외해야 함(bootstrap 자동 admin과 중복, D35) | `variables.tf`의 `eks_cluster_admin_principals`에서 생성자 제외(현재 team1-cjc 제외됨) | 운전자가 바뀌면 목록 재조정 |
| 무해 | `prometheus_adapter`가 떠 있으나 스케일은 **KEDA-only**라 미사용 | — | 후속 PR로 제거 예정 |
