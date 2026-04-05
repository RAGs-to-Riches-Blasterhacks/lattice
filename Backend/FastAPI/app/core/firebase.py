import json
import os
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

        # Debug: log what env vars are available (TEMPORARY - remove after fixing)
        print(f"[DEBUG] FIREBASE_CREDENTIALS_JSON from settings: '{settings.FIREBASE_CREDENTIALS_JSON[:20]}...' (len={len(settings.FIREBASE_CREDENTIALS_JSON)})" if settings.FIREBASE_CREDENTIALS_JSON else "[DEBUG] FIREBASE_CREDENTIALS_JSON from settings: EMPTY")
        print(f"[DEBUG] FIREBASE_CREDENTIALS_JSON from os.environ: {'SET (len=' + str(len(os.environ.get('FIREBASE_CREDENTIALS_JSON', ''))) + ')' if os.environ.get('FIREBASE_CREDENTIALS_JSON') else 'NOT SET'}")
        print(f"[DEBUG] All env vars with FIREBASE: {[k for k in os.environ if 'FIREBASE' in k]}")

        # Try env var directly (bypasses pydantic-settings) then fall back to settings
        creds_json = (
            settings.FIREBASE_CREDENTIALS_JSON
            or os.environ.get("FIREBASE_CREDENTIALS_JSON", "")
        ).strip()

        if creds_json:
            cred = credentials.Certificate(json.loads(creds_json))
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
