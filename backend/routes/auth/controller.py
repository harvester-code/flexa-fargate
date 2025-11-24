from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from packages.supabase.auth import sign_in_with_password

auth_router = APIRouter(prefix="/auth")


class LoginRequest(BaseModel):
    email: str
    password: str


@auth_router.post("/login")
async def login(login_data: LoginRequest):
    try:
        access_token = sign_in_with_password(login_data.email, login_data.password)
        return {"access_token": access_token, "token_type": "bearer"}
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

