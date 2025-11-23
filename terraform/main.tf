# ============================================================
# Terraform 설정
# ============================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================
# AWS Provider 설정
# ============================================================
provider "aws" {
  region = "ap-northeast-2"  # 서울 리전 (Fargate 지원!)
}

# ============================================================
# 데이터 소스: 기본 VPC 사용 (간단하게!)
# ============================================================
# 기본 VPC 가져오기 (모든 AWS 계정에 기본 제공)
data "aws_vpc" "default" {
  default = true
}

# 기본 VPC의 서브넷들 가져오기
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ============================================================
# 1. ECR Repository (Docker 이미지 저장소)
# ============================================================
resource "aws_ecr_repository" "app" {
  name         = "fastapi-fargate"
  force_delete = true  # destroy 시 이미지도 함께 삭제
}

# ============================================================
# 2. ECS Cluster (컨테이너 실행 환경)
# ============================================================
# ECS Cluster: 여러 서비스를 관리하는 논리적 그룹
resource "aws_ecs_cluster" "main" {
  name = "fastapi-cluster"
}

# ============================================================
# 3. IAM Role (ECS Task 실행 권한)
# ============================================================
# ECS Task가 ECR에서 이미지 다운로드하고 로그 쓰는 권한
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# AWS 관리 정책 연결 (ECR 접근 + CloudWatch 로그)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================
# 4. CloudWatch 로그 그룹 (컨테이너 로그 저장)
# ============================================================
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/fastapi-fargate"
  retention_in_days = 7  # 로그 7일 보관
}

# ============================================================
# 5. Security Group (방화벽 규칙)
# ============================================================
# ALB용 Security Group (인터넷 → ALB)
resource "aws_security_group" "alb" {
  name        = "fastapi-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = data.aws_vpc.default.id

  # 인터넷에서 HTTP 허용
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Task용 Security Group (ALB → ECS Task)
resource "aws_security_group" "ecs_task" {
  name        = "fastapi-ecs-task-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  # ALB에서만 접근 허용
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # 모든 아웃바운드 허용 (ECR 이미지 다운로드 등)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================================
# 6. Application Load Balancer (트래픽 분산)
# ============================================================
resource "aws_lb" "main" {
  name               = "fastapi-alb"
  internal           = false  # 인터넷에 공개
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
}

# Target Group (ALB가 트래픽 보낼 대상)
resource "aws_lb_target_group" "app" {
  name        = "fastapi-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"  # Fargate는 IP 모드 사용

  # 헬스체크 설정
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}

# ALB Listener (80 포트로 들어오는 요청 처리)
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ============================================================
# 7. ECS Task Definition (컨테이너 설정)
# ============================================================
resource "aws_ecs_task_definition" "app" {
  family                   = "fastapi-task"
  network_mode             = "awsvpc"  # Fargate 필수
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"   # 0.25 vCPU
  memory                   = "512"   # 0.5 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "fastapi"
    image = "${aws_ecr_repository.app.repository_url}:latest"
    
    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = "ap-northeast-2"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ============================================================
# 8. ECS Service (실제 컨테이너 실행 및 관리)
# ============================================================
resource "aws_ecs_service" "app" {
  name            = "fastapi-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1  # 실행할 Task 수 (최소 1개)
  launch_type     = "FARGATE"

  # 네트워크 설정
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = true  # 인터넷 접근 필요 (ECR 이미지 다운로드)
  }

  # ALB 연결
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "fastapi"
    container_port   = 8000
  }

  # Task Definition 변경 시 자동 배포
  depends_on = [aws_lb_listener.app]
}

# ============================================================
# 전체 흐름 요약
# ============================================================
# 1. ECR: Docker 이미지 저장소
# 2. ECS Cluster: 컨테이너 실행 환경
# 3. IAM Role: ECS가 ECR/CloudWatch 접근 권한
# 4. CloudWatch: 컨테이너 로그 저장
# 5. Security Groups: 방화벽 (ALB → 인터넷, ECS → ALB)
# 6. ALB: 트래픽 분산 + 헬스체크
# 7. Task Definition: 컨테이너 설정 (이미지, CPU, 메모리)
# 8. ECS Service: 실제 컨테이너 실행
#
# 인터넷 → ALB (80) → ECS Task (8000) → FastAPI
# ============================================================

