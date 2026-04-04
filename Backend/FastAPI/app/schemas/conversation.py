from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.conversation import ConversationPurpose, MessageRole


class MessageCreate(BaseModel):
    role: MessageRole
    content: str
    metadata: Optional[dict] = None


class MessageResponse(BaseModel):
    role: MessageRole
    content: str
    timestamp: datetime
    metadata: Optional[dict] = None


class ConversationResponse(BaseModel):
    id: str
    user_id: str
    plan_id: Optional[str] = None
    purpose: ConversationPurpose
    messages: list[MessageResponse]
    is_active: bool
    created_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime] = None
