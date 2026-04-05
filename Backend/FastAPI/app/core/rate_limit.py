"""Simple in-memory rate limiter middleware for FastAPI.

Applies globally — no per-route decorators needed.
Uses a sliding window counter keyed by client IP.

Auth endpoints get a stricter limit to prevent brute force.
"""

import time
from collections import defaultdict

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

# Requests per window
DEFAULT_LIMIT = 60       # general API: 60 req / minute
AUTH_LIMIT = 10           # auth endpoints: 10 req / minute
WINDOW_SECONDS = 60


class _TokenBucket:
    __slots__ = ("tokens", "last_refill", "capacity", "refill_rate")

    def __init__(self, capacity: int):
        self.tokens = float(capacity)
        self.last_refill = time.monotonic()
        self.capacity = capacity
        self.refill_rate = capacity / WINDOW_SECONDS  # tokens per second

    def allow(self) -> bool:
        now = time.monotonic()
        elapsed = now - self.last_refill
        self.tokens = min(self.capacity, self.tokens + elapsed * self.refill_rate)
        self.last_refill = now

        if self.tokens >= 1:
            self.tokens -= 1
            return True
        return False


# Separate buckets for general vs auth, keyed by IP
_general_buckets: dict[str, _TokenBucket] = defaultdict(lambda: _TokenBucket(DEFAULT_LIMIT))
_auth_buckets: dict[str, _TokenBucket] = defaultdict(lambda: _TokenBucket(AUTH_LIMIT))

# Paths that get the stricter auth limit
_AUTH_PREFIXES = ("/api/auth/login", "/api/auth/register", "/api/auth/oauth")


def _get_client_ip(request: Request) -> str:
    # Only trust X-Forwarded-For when behind a known proxy (e.g. Railway).
    # Railway connects via 127.0.0.1 or an internal IP; when running behind
    # a reverse proxy the direct client.host is the proxy, not the user.
    client_host = request.client.host if request.client else "unknown"
    if client_host in ("127.0.0.1", "::1"):
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
    return client_host


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        # Skip health check
        if request.url.path == "/health":
            return await call_next(request)

        client_ip = _get_client_ip(request)
        is_auth = request.url.path.startswith(_AUTH_PREFIXES)
        bucket = _auth_buckets[client_ip] if is_auth else _general_buckets[client_ip]

        if not bucket.allow():
            limit = AUTH_LIMIT if is_auth else DEFAULT_LIMIT
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests"},
                headers={
                    "Retry-After": str(WINDOW_SECONDS),
                    "X-RateLimit-Limit": str(limit),
                },
            )

        response = await call_next(request)
        return response
