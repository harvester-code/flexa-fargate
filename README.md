# FastAPI + AWS Fargate 자동 배포

**`terraform apply` 한 번에 모든 것 자동 배포!**

가장 간단한 FastAPI + AWS Fargate + Terraform 배포 (uv 사용)

## 📁 폴더 구조

```
02_fargate/
├── backend/              # FastAPI 코드
├── terraform/            # AWS 인프라 (전부 여기서 관리)
└── .github/workflows/    # 자동 배포
```

## ⭐ App Runner vs Fargate

| 항목   | App Runner | Fargate   |
| ------ | ---------- | --------- |
| 복잡도 | ⭐         | ⭐⭐      |
| 리전   | 도쿄       | 서울 ✅   |
| 유연성 | 낮음       | 높음      |
| 비용   | $5-10      | $26-30    |
| VPC    | 제한적     | 완전 제어 |

## 🚀 사용 방법

### 1단계: 로컬 개발

```bash
# uv 설치 (한 번만)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 실행
cd backend
uv sync
uv run uvicorn main:app --reload
```

→ http://localhost:8000/docs

### 2단계: GitHub 연결

```bash
# 02_fargate/ 폴더에서 실행 (프로젝트 루트)
cd /Users/yi/Desktop/flexa/flexa-waitfree-infra/02_fargate

# Git 초기화 (backend, terraform, .github 폴더 전부 포함)
git init
git add .
git commit -m "Initial commit"

# GitHub에서 새 레포 만들기
# → https://github.com/new 에서 레포 생성

# GitHub 연결 (your-username과 your-repo를 본인 것으로 변경)
git remote add origin https://github.com/your-username/your-repo.git
git branch -M main
git push -u origin main
```

**업로드되는 폴더:**

- ✅ `backend/` - FastAPI 코드
- ✅ `terraform/` - AWS 인프라 설정
- ✅ `.github/workflows/` - 자동 배포 설정

**전부 다 올라갑니다!**

**⚠️ 중요: 이제 바로 GitHub Secrets 설정하기!**

### 2-1단계: GitHub Actions Secrets 설정 (필수!)

**왜 지금 설정해야 하나?**

- Terraform으로 인프라 배포 후 git push하면 자동 배포가 시작됩니다
- 그러려면 GitHub Actions가 AWS에 접근할 수 있어야 합니다
- **지금 설정 안 하면 나중에 git push 시 배포 실패합니다!**

**설정 방법:**

1. **GitHub 레포지토리로 이동**

   - https://github.com/your-username/your-repo

2. **Settings → Secrets and variables → Actions 클릭**

   - 상단 탭에서 `Settings` 클릭
   - 왼쪽 사이드바에서 `Secrets and variables` → `Actions` 클릭

3. **New repository secret 클릭**

4. **2개의 Secret 추가:**

   **첫 번째 Secret:**

   - Name: `AWS_ACCESS_KEY_ID`
   - Secret: (AWS Access Key ID 입력)
   - `Add secret` 클릭

   **두 번째 Secret:**

   - Name: `AWS_SECRET_ACCESS_KEY`
   - Secret: (AWS Secret Access Key 입력)
   - `Add secret` 클릭

**AWS Key는 어디서?**

```bash
# 터미널에서 확인:
cat ~/.aws/credentials

# 또는 AWS 콘솔:
# IAM → Users → 본인 계정 → Security credentials → Access keys
```

**완료!** 이제 `terraform apply` 후 `git push`하면 자동 배포됩니다! ✅

### 3단계: AWS 연결 확인

```bash
# AWS 연결 확인
aws sts get-caller-identity
```

연결 안 되어 있으면:

```bash
aws configure
```

### 4단계: AWS 배포 (한 번에 끝!)

```bash
cd terraform
terraform init
terraform apply
```

**끝!** 이 명령어로 모든 것이 자동으로 실행됩니다:

✅ ECR, ECS, ALB 생성
✅ Docker 이미지 자동 빌드
✅ ECR에 자동 푸시
✅ ECS 서비스 자동 시작

**배포 시간: 약 7~10분** (ALB 생성 + Docker 빌드)

### 5단계: URL 확인

```bash
cd terraform
terraform output alb_dns_name
```

→ http://fastapi-alb-xxxxx.ap-northeast-2.elb.amazonaws.com

**접속 확인:**

```bash
curl http://fastapi-alb-xxxxx.ap-northeast-2.elb.amazonaws.com/
# {"message":"Hello from Fargate!"}
```

## ⚡ 이후 사용

```bash
git add .
git commit -m "update"
git push
```

→ 자동으로 배포됨!

**배포 시간: 2~3분** (무중단 배포)

## 🗑️ 완전 삭제

```bash
cd terraform
terraform destroy
```

→ ECR, ECS, ALB 전부 깔끔하게 삭제됨!

## 🏗️ 아키텍처

```
인터넷
  ↓
ALB (Load Balancer) - 포트 80
  ↓
ECS Fargate Task - 포트 8000
  ↓
FastAPI 앱
```

## 💰 예상 비용

```
ECS Fargate: $10-15/월
ALB: $16/월
──────────────────
합계: $26-31/월
```

## 📝 주요 특징

- ✅ **`terraform apply` 한 번에 모든 것 자동 배포!** ⭐
- ✅ 서울 리전 사용
- ✅ 기본 VPC 사용 (간단)
- ✅ Docker 이미지 자동 빌드 & 푸시
- ✅ ALB로 트래픽 분산
- ✅ 무중단 배포
- ✅ CloudWatch 로그 자동 저장
- ✅ 헬스체크 자동
- ✅ Auto Scaling 가능 (필요 시)

## 🔍 모니터링

### 로그 확인:

```bash
aws logs tail /ecs/fastapi-fargate --follow --region ap-northeast-2
```

### ECS 서비스 상태:

```bash
aws ecs describe-services \
  --cluster fastapi-cluster \
  --services fastapi-service \
  --region ap-northeast-2
```

## 🆚 App Runner와 비교

### App Runner가 나은 경우:

- 최대한 간단하게
- VPC 설정 불필요
- 도쿄 리전 OK

### Fargate가 나은 경우:

- 서울 리전 필요 ✅
- VPC 완전 제어
- DB 연결 필요
- 엔터프라이즈 기능
- 실전 경험
