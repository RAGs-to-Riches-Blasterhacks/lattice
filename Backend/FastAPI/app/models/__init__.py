from app.models.conversation import Conversation
from app.models.plan import Plan
from app.models.plan_version import PlanVersion
from app.models.streak import Streak
from app.models.user import User

ALL_DOCUMENT_MODELS = [User, Plan, PlanVersion, Conversation, Streak]

__all__ = [
    "User",
    "Plan",
    "PlanVersion",
    "Conversation",
    "Streak",
    "ALL_DOCUMENT_MODELS",
]
