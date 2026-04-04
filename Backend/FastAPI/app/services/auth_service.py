from datetime import datetime

import httpx
from firebase_admin import auth as firebase_auth

from app.core.config import settings
from app.core.firebase import get_firebase_app
from app.models.user import User

# Firebase REST API endpoint for email/password sign-in
_FIREBASE_SIGN_IN_URL = (
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
)


async def register_email(email: str, password: str, display_name: str) -> tuple[str, User]:
    """Create a Firebase user, persist to MongoDB, return (custom_token, user)."""
    get_firebase_app()

    # Create the user in Firebase
    fb_user = firebase_auth.create_user(
        email=email,
        password=password,
        display_name=display_name,
    )

    # Persist to MongoDB
    user = User(
        firebase_uid=fb_user.uid,
        email=email,
        display_name=display_name,
    )
    await user.insert()

    # Generate a custom token for the Flutter client
    custom_token = firebase_auth.create_custom_token(fb_user.uid).decode("utf-8")
    return custom_token, user


async def login_email(email: str, password: str) -> tuple[str, User]:
    """Verify email/password via Firebase REST API, return (custom_token, user)."""
    get_firebase_app()

    # Firebase Admin SDK has no server-side password verification,
    # so we hit the Firebase Auth REST API.
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            _FIREBASE_SIGN_IN_URL,
            params={"key": settings.FIREBASE_API_KEY},
            json={
                "email": email,
                "password": password,
                "returnSecureToken": True,
            },
        )

    if resp.status_code != 200:
        error_msg = resp.json().get("error", {}).get("message", "Authentication failed")
        raise ValueError(error_msg)

    firebase_uid = resp.json()["localId"]

    # Find or fail — user must exist in MongoDB
    user = await User.find_one(User.firebase_uid == firebase_uid)
    if user is None:
        raise ValueError("User not found in database")

    # Update last login
    user.last_login = datetime.utcnow()
    await user.save()

    custom_token = firebase_auth.create_custom_token(firebase_uid).decode("utf-8")
    return custom_token, user


async def login_oauth(id_token: str, provider: str) -> tuple[str, User]:
    """Verify an OAuth ID token (Google/Apple), create user if needed, return (custom_token, user)."""
    get_firebase_app()

    # Verify the token Firebase issued after Google/Apple sign-in
    decoded = firebase_auth.verify_id_token(id_token)
    firebase_uid = decoded["uid"]

    # Find existing user or create a new one
    user = await User.find_one(User.firebase_uid == firebase_uid)
    if user is None:
        fb_user = firebase_auth.get_user(firebase_uid)
        user = User(
            firebase_uid=firebase_uid,
            email=fb_user.email or "",
            display_name=fb_user.display_name or fb_user.email or "",
            avatar_url=fb_user.photo_url,
        )
        await user.insert()
    else:
        user.last_login = datetime.utcnow()
        await user.save()

    custom_token = firebase_auth.create_custom_token(firebase_uid).decode("utf-8")
    return custom_token, user
