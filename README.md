# FastAPI + AWS Fargate + Supabase Login

Supabase 로그인 API를 AWS Fargate에 배포

## 기능

- `GET /` - Hello
- `GET /health` - Health check
- `POST /api/v1/auth/login` - Supabase 로그인 (JWT 토큰 반환)

---

## 배포

### 1. 로컬 테스트 (선택)

```bash
cd backend

export SUPABASE_PROJECT_URL="https://fjptmjezetgekmpwdtbr.supabase.co"
export SUPABASE_PUBLIC_KEY="eyJhbGci..."

uv sync
uv run uvicorn main:app --reload
```

테스트:

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

### 2. AWS 배포

```bash
cd terraform
terraform init
terraform apply
```

**⏱️ 7-10분 소요**

### 3. URL 확인

```bash
terraform output alb_dns_name
```

---

## API 테스트

```bash
# Health Check
curl http://<ALB-URL>/health

# Login
curl -X POST http://<ALB-URL>/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"password"}'

# Swagger UI
# http://<ALB-URL>/docs
```

---

## 로그 확인

```bash
# 실시간 로그
aws logs tail /ecs/fastapi-fargate --follow --region ap-northeast-2

# ECS 상태
aws ecs describe-services \
  --cluster fastapi-cluster \
  --services fastapi-service \
  --region ap-northeast-2
```

---

## 코드 업데이트

```bash
cd terraform
terraform apply
```

또는:

```bash
aws ecs update-service \
  --cluster fastapi-cluster \
  --service fastapi-service \
  --force-new-deployment \
  --region ap-northeast-2
```

---

## 환경변수 변경

```bash
# terraform/terraform.tfvars 수정 후
cd terraform
terraform apply
```

---

## 삭제

```bash
cd terraform
terraform destroy
```

---

## 비용

```
ECS Fargate: $10-15/월
ALB: $16/월
Parameter Store: 무료
────────────────────
합계: $26-31/월
```

---

## 구조

```
02_fargate_v1/
├── backend/
│   ├── main.py
│   ├── pyproject.toml
│   ├── Dockerfile
│   ├── packages/supabase/
│   │   └── auth.py
│   └── routes/auth/
│       └── controller.py
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars  # Supabase 설정
```
