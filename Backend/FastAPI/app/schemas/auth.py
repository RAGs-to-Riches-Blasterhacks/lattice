from typing import Optional

from pydantic import BaseModel, EmailStr

from app.models.user import LocationPrefs
from app.schemas.user import UserResponse


class EmailRegisterRequest(BaseModel):
    email: EmailStr
    password: str
    display_name: str
    timezone: Optional[str] = None
    location: Optional[LocationPrefs] = None


class EmailLoginRequest(BaseModel):
    email: EmailStr
    password: str


class OAuthTokenRequest(BaseModel):
    """Flutter sends the OAuth ID token obtained from Google/Apple sign-in."""
    id_token: str
    provider: str  # "google" or "apple"


class AuthResponse(BaseModel):
    id_token: str  # Firebase ID token — use as Bearer token for authenticated requests
    refresh_token: str  # Firebase refresh token — use to get a new id_token when it expires
    custom_token: str  # Firebase custom token — Flutter uses this with signInWithCustomToken()
    user: UserResponse
