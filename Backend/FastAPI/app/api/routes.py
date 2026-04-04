from fastapi import APIRouter

from app.api.auth import router as auth_router
from app.api.conversations import router as conversations_router
from app.api.plans import router as plans_router
from app.api.streaks import router as streaks_router
from app.api.users import router as users_router

router = APIRouter()
router.include_router(auth_router)
router.include_router(plans_router)
router.include_router(conversations_router)
router.include_router(streaks_router)
router.include_router(users_router)
