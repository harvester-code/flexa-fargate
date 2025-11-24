FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

WORKDIR /app

# 의존성 설치
COPY pyproject.toml .
RUN uv sync --no-dev

# 애플리케이션 코드 복사
COPY main.py .
COPY packages/ ./packages/
COPY routes/ ./routes/

EXPOSE 8000

CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]


