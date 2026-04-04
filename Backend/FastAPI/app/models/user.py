from datetime import datetime
from typing import Optional

import pymongo
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
    friend_code: Optional[str] = None
    friends: list[PydanticObjectId] = Field(default_factory=list)
    is_active: bool = True

    class Settings:
        name = "users"
        indexes = [
            pymongo.IndexModel(
                [("friend_code", pymongo.ASCENDING)],
                unique=True,
                sparse=True,
            ),
        ]
        bson_encoders = {type(None): lambda _: None}

    async def insert(self, *args, **kwargs):
        result = await super().insert(*args, **kwargs)
        # Sparse unique index requires the field to be absent (not null)
        if self.friend_code is None:
            await self.get_motor_collection().update_one(
                {"_id": self.id}, {"$unset": {"friend_code": ""}}
            )
        return result

    async def save(self, *args, **kwargs):
        result = await super().save(*args, **kwargs)
        if self.friend_code is None:
            await self.get_motor_collection().update_one(
                {"_id": self.id}, {"$unset": {"friend_code": ""}}
            )
        return result
