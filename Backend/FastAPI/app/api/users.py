from datetime import datetime

from fastapi import APIRouter, Depends

from app.core.security import get_current_user
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


def _user_response(user: User) -> UserResponse:
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
        is_active=user.is_active,
    )


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    """Get the current user's profile."""
    return _user_response(user)


@router.patch("/me", response_model=UserResponse)
async def update_me(body: UserUpdate, user: User = Depends(get_current_user)):
    """Update the current user's profile."""
    changes = body.model_dump(exclude_none=True)
    for field, value in changes.items():
        setattr(user, field, value)
    user.updated_at = datetime.utcnow()
    await user.save()
    return _user_response(user)
