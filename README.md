# FastAPI + AWS Fargate 자동 배포

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

### 3단계: AWS 연결 확인

```bash
# AWS 연결 확인
aws sts get-caller-identity
```

연결 안 되어 있으면:

```bash
aws configure
```

### 4단계: AWS 배포

```bash
cd terraform
terraform init
terraform apply
```

끝! ECR, ECS, ALB 전부 자동 생성됨.

**배포 시간: 약 5~7분** (ALB 생성에 시간 소요)

### 5단계: 최초 이미지 푸시 (중요!)

Fargate는 초기 이미지가 필요합니다:

```bash
# ECR URL 확인
cd terraform
terraform output ecr_repository_url

# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <ECR_URL>

# 이미지 빌드 & 푸시
cd ../backend
docker build -t <ECR_URL>:latest .
docker push <ECR_URL>:latest

# ECS 서비스 업데이트
aws ecs update-service \
  --cluster fastapi-cluster \
  --service fastapi-service \
  --force-new-deployment \
  --region ap-northeast-2
```

### 6단계: URL 확인

```bash
cd terraform
terraform output alb_dns_name
```

→ http://fastapi-alb-xxxxx.ap-northeast-2.elb.amazonaws.com

### 7단계: GitHub Actions Secrets 설정

**왜 필요한가?**
GitHub Actions가 AWS에 자동 배포하려면 AWS 자격증명이 필요합니다.

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
# AWS 콘솔 → IAM → Users → 본인 계정 → Security credentials → Access keys
# 또는 터미널에서:
cat ~/.aws/credentials
```

**완료!** `git push`하면 GitHub Actions가 AWS에 자동 배포합니다.

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

- ✅ 서울 리전 사용
- ✅ 기본 VPC 사용 (간단)
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
