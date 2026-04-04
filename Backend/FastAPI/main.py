from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import router
from app.core.database import close_db, init_db
from app.core.firebase import init_firebase
from app.core.rate_limit import RateLimitMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_firebase()
    await init_db()
    yield
    await close_db()


app = FastAPI(title="Lattice API", version="0.1.0", lifespan=lifespan)
app.add_middleware(RateLimitMiddleware)

app.include_router(router, prefix="/api")


@app.get("/health")
def health_check():
    return {"status": "ok"}
