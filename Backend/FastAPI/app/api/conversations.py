from datetime import datetime

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.security import get_current_user
from app.models.conversation import Conversation, Message
from app.models.user import User
from app.schemas.conversation import (
    ConversationResponse,
    MessageCreate,
    MessageResponse,
)

router = APIRouter(prefix="/conversations", tags=["conversations"])


def _conversation_response(conv: Conversation) -> ConversationResponse:
    return ConversationResponse(
        id=str(conv.id),
        user_id=str(conv.user_id),
        plan_id=str(conv.plan_id) if conv.plan_id else None,
        messages=[
            MessageResponse(
                role=m.role,
                content=m.content,
                timestamp=m.timestamp,
                metadata=m.metadata,
            )
            for m in conv.messages
        ],
        is_active=conv.is_active,
        created_at=conv.created_at,
        updated_at=conv.updated_at,
        completed_at=conv.completed_at,
    )


async def _get_user_conversation(conv_id: str, user: User) -> Conversation:
    conv = await Conversation.get(conv_id)
    if conv is None or conv.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found"
        )
    return conv


@router.post("", response_model=ConversationResponse, status_code=status.HTTP_201_CREATED)
async def create_conversation(
    plan_id: str | None = None,
    user: User = Depends(get_current_user),
):
    """Start a new conversation, optionally tied to a plan."""
    conv = Conversation(
        user_id=user.id,
        plan_id=PydanticObjectId(plan_id) if plan_id else None,
    )
    await conv.insert()
    return _conversation_response(conv)


@router.get("", response_model=list[ConversationResponse])
async def list_conversations(
    plan_id: str | None = Query(None),
    active_only: bool = Query(True),
    user: User = Depends(get_current_user),
):
    """List conversations for the current user, optionally filtered by plan."""
    query = {"user_id": user.id}
    if plan_id:
        query["plan_id"] = PydanticObjectId(plan_id)
    if active_only:
        query["is_active"] = True
    convs = await Conversation.find(query).to_list()
    return [_conversation_response(c) for c in convs]


@router.get("/{conv_id}", response_model=ConversationResponse)
async def get_conversation(conv_id: str, user: User = Depends(get_current_user)):
    """Fetch a conversation with its full message history."""
    conv = await _get_user_conversation(conv_id, user)
    return _conversation_response(conv)


@router.post("/{conv_id}/messages", response_model=ConversationResponse)
async def send_message(
    conv_id: str,
    body: MessageCreate,
    user: User = Depends(get_current_user),
):
    """Append a message to the conversation.

    This is the integration point for the ADK agent: the client sends a user
    message, your agent processes it, and appends the assistant response.
    """
    conv = await _get_user_conversation(conv_id, user)
    if not conv.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Conversation is closed",
        )

    conv.messages.append(
        Message(
            role=body.role,
            content=body.content,
            metadata=body.metadata,
        )
    )
    conv.updated_at = datetime.utcnow()
    await conv.save()
    return _conversation_response(conv)


@router.post("/{conv_id}/complete", response_model=ConversationResponse)
async def complete_conversation(conv_id: str, user: User = Depends(get_current_user)):
    """Mark a conversation as completed (starts the 60-day TTL)."""
    from datetime import timedelta

    conv = await _get_user_conversation(conv_id, user)
    now = datetime.utcnow()
    conv.is_active = False
    conv.completed_at = now
    conv.expires_at = now + timedelta(days=60)
    conv.updated_at = now
    await conv.save()
    return _conversation_response(conv)
