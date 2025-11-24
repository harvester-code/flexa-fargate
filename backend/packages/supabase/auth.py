import os
from fastapi import HTTPException, status
from supabase import create_client


def get_supabase_client():
    url = os.environ.get("SUPABASE_PROJECT_URL")
    key = os.environ.get("SUPABASE_PUBLIC_KEY")

    if not url or not key:
        raise ValueError("SUPABASE_PROJECT_URL and SUPABASE_PUBLIC_KEY required")

    return create_client(url, key)


def sign_in_with_password(email: str, password: str) -> str:
    supabase = get_supabase_client()
    
    try:
        response = supabase.auth.sign_in_with_password(
            {"email": email, "password": password}
        )

        if not response.session or not response.session.access_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )

        return response.session.access_token
    
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

