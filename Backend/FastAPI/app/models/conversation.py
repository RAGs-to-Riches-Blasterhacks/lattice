from datetime import datetime
from enum import Enum
from typing import Optional

from beanie import Document, Indexed, PydanticObjectId
from pydantic import BaseModel, Field
from pymongo import IndexModel


class MessageRole(str, Enum):
    user = "user"
    assistant = "assistant"
    system = "system"



class Message(BaseModel):
    role: MessageRole
    content: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    metadata: Optional[dict] = None


class Conversation(Document):
    user_id: PydanticObjectId
    plan_id: Optional[PydanticObjectId] = None
    messages: list[Message] = Field(default_factory=list)
    is_active: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None

    class Settings:
        name = "conversations"
        indexes = [
            [("user_id", 1), ("is_active", 1)],
            [("user_id", 1), ("plan_id", 1)],
            IndexModel([("expires_at", 1)], expireAfterSeconds=0),
        ]
