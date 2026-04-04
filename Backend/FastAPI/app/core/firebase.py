import firebase_admin
from firebase_admin import credentials

from app.core.config import settings

_app: firebase_admin.App | None = None


def init_firebase() -> firebase_admin.App:
    """Initialise the Firebase Admin SDK. Safe to call multiple times."""
    global _app
    if _app is not None:
        return _app

    cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
    _app = firebase_admin.initialize_app(cred)
    return _app


def get_firebase_app() -> firebase_admin.App:
    if _app is None:
        return init_firebase()
    return _app
