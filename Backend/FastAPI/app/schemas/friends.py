from pydantic import BaseModel


class AddFriendRequest(BaseModel):
    friend_code: str


class FriendCodeResponse(BaseModel):
    friend_code: str


class FriendInfo(BaseModel):
    user_id: str
    name: str
    handle: str
    streak: int
    current_task: str
    completed_days: int
    total_days: int


class FriendsListResponse(BaseModel):
    friends: list[FriendInfo]
