import json
import threading

import firebase_admin
from firebase_admin import credentials

from app.core.config import settings

_app: firebase_admin.App | None = None
_init_lock = threading.Lock()


def init_firebase() -> firebase_admin.App:
    """Initialise the Firebase Admin SDK. Safe to call multiple times."""
    global _app
    if _app is not None:
        return _app

    with _init_lock:
        # Double-check after acquiring lock
        if _app is not None:
            return _app

        if settings.FIREBASE_CREDENTIALS_JSON and settings.FIREBASE_CREDENTIALS_JSON.strip():
            cred = credentials.Certificate(json.loads(settings.FIREBASE_CREDENTIALS_JSON))
        elif settings.FIREBASE_CREDENTIALS_PATH:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        else:
            raise RuntimeError(
                "Firebase credentials not configured. "
                "Set FIREBASE_CREDENTIALS_JSON or FIREBASE_CREDENTIALS_PATH."
            )
        _app = firebase_admin.initialize_app(cred)
        return _app


def get_firebase_app() -> firebase_admin.App:
    if _app is None:
        return init_firebase()
    return _app
