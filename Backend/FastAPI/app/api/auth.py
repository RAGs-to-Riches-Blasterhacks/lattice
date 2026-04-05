from fastapi import APIRouter, HTTPException

from app.schemas.auth import (
    AuthResponse,
    EmailLoginRequest,
    EmailRegisterRequest,
    OAuthTokenRequest,
)
from app.schemas.user import UserResponse
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


def _user_response(user) -> UserResponse:
    return UserResponse(
        id=str(user.id),
        firebase_uid=user.firebase_uid,
        email=user.email,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        timezone=user.timezone,
        location=user.location,
        notifications=user.notifications,
        created_at=user.created_at,
        updated_at=user.updated_at,
        last_login=user.last_login,
        friend_code=user.friend_code,
        is_active=user.is_active,
    )


@router.post("/register", response_model=AuthResponse)
async def register(body: EmailRegisterRequest):
    """Create a new account with email and password."""
    try:
        tokens, user = await auth_service.register_email(
            email=body.email,
            password=body.password,
            display_name=body.display_name,
            timezone=body.timezone,
            location=body.location,
        )
    except Exception:
        raise HTTPException(status_code=400, detail="Registration failed")

    return AuthResponse(**tokens, user=_user_response(user))


@router.post("/login", response_model=AuthResponse)
async def login(body: EmailLoginRequest):
    """Sign in with email and password."""
    try:
        tokens, user = await auth_service.login_email(
            email=body.email,
            password=body.password,
        )
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    return AuthResponse(**tokens, user=_user_response(user))


@router.post("/oauth", response_model=AuthResponse)
async def oauth_login(body: OAuthTokenRequest):
    """Exchange a Google or Apple OAuth token for a Lattice session."""
    if body.provider not in ("google", "apple"):
        raise HTTPException(status_code=400, detail="Provider must be 'google' or 'apple'")

    try:
        tokens, user = await auth_service.login_oauth(
            id_token=body.id_token,
            provider=body.provider,
        )
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication failed")

    return AuthResponse(**tokens, user=_user_response(user))
