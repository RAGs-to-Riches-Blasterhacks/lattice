from pydantic import BaseModel, EmailStr

from app.schemas.user import UserResponse


class EmailRegisterRequest(BaseModel):
    email: EmailStr
    password: str
    display_name: str


class EmailLoginRequest(BaseModel):
    email: EmailStr
    password: str


class OAuthTokenRequest(BaseModel):
    """Flutter sends the OAuth ID token obtained from Google/Apple sign-in."""
    id_token: str
    provider: str  # "google" or "apple"


class AuthResponse(BaseModel):
    custom_token: str  # Firebase custom token — Flutter uses this to sign in
    user: UserResponse
