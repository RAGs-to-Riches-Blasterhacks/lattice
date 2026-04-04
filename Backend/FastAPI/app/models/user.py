from datetime import datetime
from typing import Optional

from beanie import Document, Indexed, PydanticObjectId
from pydantic import BaseModel, Field


class LocationPrefs(BaseModel):
    opted_in: bool = False
    city: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None


class NotificationPrefs(BaseModel):
    push_enabled: bool = True
    email_enabled: bool = True
    reminder_time: Optional[str] = None


class User(Document):
    firebase_uid: Indexed(str, unique=True)
    email: Indexed(str, unique=True)
    display_name: str
    avatar_url: Optional[str] = None
    timezone: str = "UTC"
    location: LocationPrefs = Field(default_factory=LocationPrefs)
    notifications: NotificationPrefs = Field(default_factory=NotificationPrefs)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    last_login: Optional[datetime] = None
    friend_code: Indexed(str, unique=True, sparse=True) = None
    friends: list[PydanticObjectId] = Field(default_factory=list)
    is_active: bool = True

    class Settings:
        name = "users"
