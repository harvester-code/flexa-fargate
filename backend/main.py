from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routes.auth.controller import auth_router

app = FastAPI(
    title="Flexa Fargate API",
    description="FastAPI with Supabase Authentication on AWS Fargate",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/v1", tags=["Authentication"])


@app.get("/")
def read_root():
    return {"message": "Hello from Fargate!", "version": "0.1.0"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}


