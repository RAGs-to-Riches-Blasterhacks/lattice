from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.user import LocationPrefs, NotificationPrefs


class UserCreate(BaseModel):
    firebase_uid: str
    email: str
    display_name: str
    avatar_url: Optional[str] = None
    timezone: str = "UTC"


class UserUpdate(BaseModel):
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    timezone: Optional[str] = None
    location: Optional[LocationPrefs] = None
    notifications: Optional[NotificationPrefs] = None


class UserResponse(BaseModel):
    id: str
    firebase_uid: str
    email: str
    display_name: str
    avatar_url: Optional[str] = None
    timezone: str
    location: LocationPrefs
    notifications: NotificationPrefs
    created_at: datetime
    updated_at: datetime
    last_login: Optional[datetime] = None
    friend_code: Optional[str] = None
    is_active: bool
