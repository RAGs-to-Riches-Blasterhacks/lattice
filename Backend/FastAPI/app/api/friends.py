from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import get_current_user
from app.models.user import User
from app.schemas.friends import (
    AddFriendRequest,
    FriendCodeResponse,
    FriendInfo,
    FriendsListResponse,
)
from app.services import friend_service

router = APIRouter(prefix="/friends", tags=["friends"])


@router.get("/code", response_model=FriendCodeResponse)
async def get_my_friend_code(user: User = Depends(get_current_user)):
    """Get or generate the current user's friend code."""
    code = await friend_service.ensure_friend_code(user)
    return FriendCodeResponse(friend_code=code)


@router.get("", response_model=FriendsListResponse)
async def list_friends(user: User = Depends(get_current_user)):
    """List all friends with their stats."""
    friends = await friend_service.get_all_friends_info(user)
    return FriendsListResponse(friends=[FriendInfo(**f) for f in friends])


@router.post("/add", response_model=FriendInfo, status_code=status.HTTP_201_CREATED)
async def add_friend(body: AddFriendRequest, user: User = Depends(get_current_user)):
    """Add a friend by their friend code."""
    try:
        target = await friend_service.add_friend_by_code(user, body.friend_code)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    info = await friend_service.get_friend_info(target)
    return FriendInfo(**info)


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_friend(user_id: str, user: User = Depends(get_current_user)):
    """Remove a friend."""
    try:
        await friend_service.remove_friend(user, PydanticObjectId(user_id))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
