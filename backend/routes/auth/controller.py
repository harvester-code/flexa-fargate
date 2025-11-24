from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr

from packages.supabase.auth import sign_in_with_password

auth_router = APIRouter(prefix="/auth")


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


@auth_router.post("/login", response_model=LoginResponse)
async def login(login_data: LoginRequest) -> LoginResponse:
    try:
        access_token = sign_in_with_password(login_data.email, login_data.password)
        return LoginResponse(access_token=access_token)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}",
        )

