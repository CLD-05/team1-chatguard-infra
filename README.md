# team1-chatguard-infra

ChatGuard의 **Terraform IaC 전용** 레포 (`modules/` + `envs/dev`·`envs/prod`). 서울 리전(`ap-northeast-2`)·계정 `495599735720`·프로필 `final` 전용. AWS 인증은 OIDC(Access Key 금지).

> 설계·결정 기록의 **SSoT는 `../team1-chatguard-context`** (팀 규칙 `CLAUDE.md` · 설계 `DESIGN.md`). 이 레포 전용 규칙은 `./CLAUDE.md`. 본 README는 **dev 환경 apply/destroy 운영 절차**에 집중한다.
>
> ⚠️ dev state는 공유 → **apply/destroy는 한 명(운전자)이 수행**, 나머지는 PR로 기여. **destroy·prod 변경 전에는 반드시 사람 확인.**
>
> 🕘 **AWS 작업 가능 시간 = 매일 09:00 ~ 18:00** (CLAUDE.md §0). 이 밖에는 `team1-xxx` 자격증명이 정책으로 차단된다. **18:00 임박 시 destroy를 시작하지 말 것** — EKS/VPC 삭제는 10~20분 걸리고, 중간에 차단되면 state가 꼬이고 orphan이 남는다(2026-06-23 사고, Known Issues 사고① 참조).

## 구조

### 🔐 시크릿 자산 분류 및 소유권 체계 (CLAUDE.md §4 준수)

| 자산 분류 | 공급처 (Source) | 포함 항목 (Examples) | 비고 |
| :--- | :--- | :--- | :--- |
| **안정성 고정값** | **ConfigMap (`base/configmap.yaml`)** | `REDIS_PORT: "6379"`, `MOD_QUEUE_KEY: "mod:queue"`, `ROOM_CHANNEL_PREFIX: "room:"`, `MODEL_VERSION: "unsmile-weighted-v1"` | Git에 기록하고 투명하게 공유하기 적합한 비민감성 규격 정보 (PR #38 정렬 완료) |
| **변동성 및 보안 자산** | **Secrets Manager (수동/IaC)**<br>`team1-dev-database-credentials` | `JWT_SECRET` | 테라폼에 의해 관리되거나 앱 인증에 필요한 공용 보안 자산 |

---

두 개의 **독립 Terraform 루트**(각자 `.terraform.lock.hcl`·state). apply는 **① infra → ② platform-addons** 순서 — EKS가 떠야 그 위 Helm 설치가 가능하다.

| 루트                       | state key (S3 `tfstate-lionkdt5-team1`)       | 만드는 것                                                                                                                        |
| -------------------------- | --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `envs/dev/infra`           | `team1/dev/infra/terraform.tfstate`           | VPC · EKS(+노드그룹) · RDS(MySQL) · ElastiCache(Redis) · ECR×3 · IRSA용 OIDC provider · IAM · Secrets Manager **금고(컨테이너)** |
| `envs/dev/platform-addons` | `team1/dev/platform-addons/terraform.tfstate` | Helm: ArgoCD · kube-prometheus-stack · KEDA · LBC · ESO · redis_exporter · prometheus-adapter + LBC/ESO IRSA role                |

- 백엔드: S3 네이티브 락(`use_lockfile=true`, DynamoDB 미사용)·`encrypt=true`.
- 앱 Deployment/Service/Ingress·HPA·KEDA ScaledObject·ServiceMonitor·ExternalSecret 등은 **여기서 안 만든다** → config 레포(GitOps/ArgoCD) 소유 (CLAUDE.md §4).
- `modules/`는 검증본(공유). dev/prod는 **디렉터리**로 분리(브랜치 아님), 차이는 tfvars로만.

> ⚠️ **소유 경계와 destroy의 관계** (CLAUDE.md §4): ALB/NLB는 Terraform이 아니라 **LBC(파드)가 Ingress·LoadBalancer Service를 보고** 만든다. 이 LBC 생성물은 Terraform `default_tags`가 **안 타서 `Team` 태그가 비어 있다.** destroy 시 이 점이 사고를 부른다 → Destroy 섹션·Known Issues 사고① 필독.

## 사전 준비

```bash
export AWS_PROFILE=final          # 계정 495599735720 · ap-northeast-2
aws sts get-caller-identity       # team1-* 유저인지 확인 (자격증명 살아있는지도 겸사 확인)
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
#    LBC webhook race로 1회 실패할 수 있음 → 아래로 LBC 파드 Running 확인 후 재apply하면
#    Terraform이 실패 릴리스를 정리하고 재생성한다(검증됨).
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

> ✅ **2026-06-23 실제 destroy 1회 완료** (이전 "미실행 검증" 상태 해소). 단, 그 과정에서 **야간 차단 중단 + orphan 막힘 사고**가 발생했고 손으로 복구했다 — 아래 순서를 반드시 지키고, 막히면 "Destroy 중 막힘 복구"·Known Issues 사고①을 따른다.
>
> **순서가 핵심.** ALB/NLB는 Terraform이 아니라 **LBC(파드)가 Ingress·LoadBalancer Service를 보고** 만든다(CLAUDE.md §4). LBC(클러스터)를 먼저 지우면 LB·SG가 **고아(orphan)** 로 남고, 그 orphan은 `Team` 태그가 없어 삭제 정책(`DenyOtherTeamResources-team1`)에까지 막힌다 → 공유 계정·다른 팀에 피해(§1). **워크로드부터 회수하고, 컨트롤러는 나중에.**
>
> 🕘 **시작 전 시간 확인**: destroy는 EKS/VPC까지 15~20분 이상 걸린다. **남은 작업 시간이 30분 미만이면 시작하지 말 것** (18:00 차단에 중간에 끊기면 state 꼬임 + orphan).

> ✅ **2026-06-24 실전 destroy 및 야간 차단 락 복구 공정 최종 검증 완료 (완전 검증 완료 상태)**
> 단, 그 과정에서 야간 차단 중단 + 연쇄 타임아웃 멈춤 사고가 발생할 수 있으므로 아래 순서를 반드시 지키고, 막히면 "Destroy 중 막힘 복구" 및 Known Issues 절차를 따릅니다.
> 
```bash
# ⓪ 시작 전 — 자격증명·시간 여유 확인
aws sts get-caller-identity        # team1-xxx 정상 응답 확인 (InvalidAccessKeyId면 차단 시간대)

# ① ⭐ (config/app이 ArgoCD로 배포된 경우) k8s 워크로드 선회수 — LBC가 LB·SG를 스스로 회수하게 함 (D49)
#    Phase 0만 올린 상태(앱 미배포)라도 ArgoCD 자체가 LB 타입 Service라 NLB를 갖는다 → 아래 ②까지 수행.
kubectl delete ingress --all -A                  # LBC가 만든 ALB 회수
#    ArgoCD Application으로 배포했다면 해당 app을 먼저 제거(재싱크로 되살아남 방지)

# ② ⭐ LoadBalancer 타입 Service도 회수 — `delete ingress`만으론 NLB가 안 잡힌다 (2026-06-23 사고의 핵심)
kubectl get svc -A --field-selector spec.type=LoadBalancer    # 어떤 LB 타입 Service가 있나 확인
#    ArgoCD server 등이 보이면, 그 Service를 지우거나(아래 ③ platform-addons destroy가 정리해 주기도 함)
#    가장 확실한 방법은 ③ 전에 LB가 회수됐는지 확인하는 것:
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?VpcId=='<우리_VPC_ID>'].[LoadBalancerName,Type]" --output table
#    → 우리 VPC에 LB가 남아있지 않은 상태에서 ③로 진행 (남아있으면 위 k8s 오브젝트부터 제거)

# ③ platform-addons destroy (클러스터가 살아있는 동안 — provider가 클러스터에 접속)
cd envs/dev/platform-addons
terraform destroy -var-file=terraform.tfvars
# ⚠️ Known Issues: ArgoCD/Helm 자식 리소스 해제 지연으로 `context deadline exceeded` 타임아웃이 발생할 수 있습니다. 
# 당황하지 말고 그 자리에서 `terraform destroy`를 1회 더 재시도(Retry)하면 찌꺼기가 완벽하게 청소되며 완료됩니다 (2026-06-24 실증 완료).

# ④ infra destroy (클러스터·VPC·RDS·Redis·ECR·시크릿 금고 제거)
cd ../infra
terraform destroy -var-file=terraform.tfvars
#   grafana 금고: recovery_window_in_days=0 → 즉시 삭제 → 다음 apply 때 Apply ③ 재주입 필요
#   ECR: force_delete=true(dev)라 이미지가 있어도 삭제됨

# ⑤ 최종 검증 — state(장부)와 실제 AWS가 둘 다 비었는지
terraform state list                                                                          # 빈 출력 = 정상
aws ec2 describe-vpcs --filters "Name=tag:Team,Values=team1" --query 'Vpcs[*].VpcId' --output table          # 빈 출력 = 정상
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName,'team1')].LoadBalancerName" --output table   # 빈 출력 = orphan LB 없음
```

## Destroy 중 막힘 복구 (2026-06-23 실증 절차)

destroy가 **한 리소스에서 1분 이상 멈추면** orphan이 그 리소스를 붙잡은 것이다(빈 서브넷/VPC는 수초 내 삭제). **멈춘 창은 `Ctrl+C`로 끊지 말고**(state 꼬임 위험), **새 터미널**에서 원인을 찾아 제거한다.

```bash
# A) 서브넷이 안 지워질 때 — 보통 LBC NLB의 ENI가 붙잡음
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=<서브넷ID들 콤마구분>" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' --output table
#   → Description에 'ELB net/...' 보이면 그 NLB가 범인. ENI를 직접 지우지 말고 NLB를 지운다(ENI는 따라서 풀림).

# B) VPC가 안 지워질 때 — 보통 LBC가 만든 보안그룹(SG)이 붙잡음
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=<우리_VPC_ID>" \
  --query 'SecurityGroups[?GroupName!=`default`].[GroupId,GroupName]' --output table
#   → k8s-traffic-... / k8s-argocd-... 등이 보이면 그 SG가 범인.

# C) orphan(NLB·SG) 삭제 — ⚠️ 반드시 우리 것인지 먼저 확인하고, Team 태그를 붙인 뒤 삭제
#    (LBC 생성물은 Team 태그가 없어 DenyOtherTeamResources-team1 정책에 막힘 → 태그 부착이 열쇠)
#    소유권 확인: VpcId가 우리 VPC인지 + 태그 elbv2.k8s.aws/cluster=team1-dev-cluster 인지
#    ⚠️ 같은 이름 prefix(k8s-argocd-…)의 '다른 팀' 리소스가 함께 조회될 수 있다 — VpcId로 반드시 구분! (CLAUDE.md §1-3)

# NLB 예:
aws elbv2 add-tags        --resource-arns <우리_NLB_ARN> --tags Key=Team,Value=team1
aws elbv2 delete-load-balancer --load-balancer-arn <우리_NLB_ARN>     # → ENI 자동 해제 → 서브넷 풀림

# SG 예:
aws ec2 create-tags         --resources <sg1> <sg2> --tags Key=Team,Value=team1
aws ec2 delete-security-group --group-id <sg1>
aws ec2 delete-security-group --group-id <sg2>                        # → VPC 풀림
#   SG 둘이 서로 참조하면 DependencyViolation → 순서 바꿔 둘 다 시도하면 풀림
```

> 근본 예방책(D49 안전망): LBC 생성물에 `Team` 표준 태그를 어노테이션으로 자동 부착하면, orphan으로 남아도 위 `add-tags` 단계 없이 바로 삭제된다. **소유 경계(CLAUDE.md §4)에 따라 어느 레포에 다는지가 갈린다:**
>
> - **ArgoCD Service(NLB)** → **infra 레포**(이 레포) `platform-addons` Helm values의 `server.service.annotations`:
>
> ```yaml
> service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "Team=team1,Environment=dev,Project=chatguard,Owner=infra-lead"
> ```
>
> - **앱 Ingress(ALB)** → **config 레포** Ingress 어노테이션(`alb.ingress.kubernetes.io/tags`, GitOps 소유).

## state 꼬임 복구 (야간 차단 등으로 destroy/apply가 끊긴 경우)

차단·네트워크 등으로 state 저장에 실패하면 로컬에 `errored.tfstate`가 남고 S3 락이 안 풀린다. 다음 작업 시간(09:00 이후)에:

```bash
aws sts get-caller-identity --profile final     # 1) 자격증명 부활 확인

# 2) 남은 락 확인 후 해제 (Who가 본인이고 진행 중 run이 없을 때만)
aws s3 cp s3://tfstate-lionkdt5-team1/team1/dev/infra/terraform.tfstate.tflock - --profile final
terraform force-unlock <LOCK_ID>

# 3) 로컬 vs S3 최신성 비교 (serial 큰 쪽이 최신, lineage 같아야 함)
terraform state pull > backend-state.json
grep -E '"serial"|"lineage"' backend-state.json
grep -E '"serial"|"lineage"' errored.tfstate
#   로컬(errored) serial이 더 크면 로컬이 최신 → push

# 4) 최신 로컬 state를 S3에 반영 (push가 serial을 +1 올리는 건 정상)
terraform state push errored.tfstate
terraform state pull | grep '"serial"'

# 5) 이어서 destroy/apply 재개 (refresh가 이미 처리된 리소스를 자동 정리)
terraform plan -destroy        # 무엇이 남았는지 먼저 확인
terraform destroy
```

> ⚠️ state가 꼬인 상태에서 `apply`/`destroy`를 무작정 재시도하면 **fork된 state**가 생겨 복구가 더 어려워진다. 반드시 위 순서(락 해제 → 최신성 비교 → push)부터.

## Known Issues & 후속

| #     | 현상                                                                                                                                                                               | 임시 조치                                                                                        | 후속 개선                                                                                                                        |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| 사고① | **(2026-06-23 실증)** destroy 중단 시 LBC 생성물(NLB·SG)이 `Team` 태그 없이 orphan으로 남아 서브넷·VPC 삭제를 막고, 정책(`DenyOtherTeamResources-team1`)에 막혀 수동 삭제도 거부됨 | ① destroy 전 k8s 워크로드 선회수(Destroy ①②) ② 막히면 "Destroy 중 막힘 복구"로 `add-tags`→delete | **infra 레포 Helm(ArgoCD Service NLB) + config 레포 앱 Ingress(ALB)에 `Team` 표준 태그 어노테이션 추가(D49 안전망)** + CLAUDE.md §4 체크리스트에 "LB 타입 Service 삭제" 명시 |
| 사고② | **(2026-06-23 실증)** 18:00 차단으로 destroy가 끊겨 state 저장 실패·락 미해제(`errored.tfstate` 잔존)                                                                              | "state 꼬임 복구" 절차                                                                           | 18:00 임박 시 destroy 미착수(운영 수칙)                                                                                          |
| 수동① | grafana 시크릿을 매 apply 전 수동 주입(`recovery_window=0`이라 destroy 시 소멸)                                                                                                    | Apply ③의 `put-secret-value`                                                                     | ESO로 Secrets Manager 동기화(D34 최종형, config 소관) → plan이 시크릿 값에 의존하지 않게 되어 제거                               |
| 수동② | platform-addons apply가 LBC webhook race로 1회 실패 가능                                                                                                                           | LBC 파드 Running 확인 후 재apply                                                                 | prometheus_stack 등에 LBC readiness 대기(`depends_on`)                                                                           |
| 설계  | EKS access entry 409 — **운전자=클러스터 생성자**는 admin 목록에서 제외해야 함(bootstrap 자동 admin과 중복, D35)                                                                   | `variables.tf`의 `eks_cluster_admin_principals`에서 생성자 제외(현재 team1-cjc 제외됨)           | 운전자가 바뀌면 목록 재조정                                                                                                      |
| 무해  | `prometheus_adapter`가 떠 있으나 스케일은 **KEDA-only**라 미사용                                                                                                                   | —                                                                                                | 후속 PR로 제거 예정                                                                                                              |
| 사고③ | **(2026-06-24 실증)** 테라폼 명령어 또는 변수 명단 주입 시 주소(ARN) 양옆에 백틱(`` ` ``)을 사용하면 `Invalid character` 및 `Index value required` 에러 발생 | 백틱(`` ` ``) 문자를 모두 제거하고, 테라폼 표준 규격인 쌍따옴표(`"`) 문자열로 치환하여 실행 | 향후 복붙 가이드라인 및 코드 리뷰 시 쌍따옴표 검증 강제 |
| 사고④ | **(2026-06-24 실증)** 18:00 야간 차단 진입 후 `destroy/apply` 수행 시 `DeleteSubnet 403 UnauthorizedOperation` 및 `S3 PutObject AccessDenied` 에러와 함께 `errored.tfstate` 파편 발생 | 즉시 작업을 중단하고 다음 날 09:00 권한 부활 후 `terraform force-unlock <LOCK_ID>` -> `terraform state push errored.tfstate` 순으로 장부 수선 후 재개 | 18:00 임박 시 destroy 절대 착수 금지 수칙 엄수 및 인계서 행동 요령 인입 |
