from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings

_client: AsyncIOMotorClient | None = None


async def init_db() -> None:
    global _client
    from app.models import ALL_DOCUMENT_MODELS

    _client = AsyncIOMotorClient(settings.MONGO_URI)
    await init_beanie(
        database=_client[settings.MONGO_DB_NAME],
        document_models=ALL_DOCUMENT_MODELS,
    )


async def close_db() -> None:
    global _client
    if _client is not None:
        _client.close()
        _client = None
