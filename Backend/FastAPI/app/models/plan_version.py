from datetime import datetime, timedelta
from typing import Optional

from beanie import Document, PydanticObjectId
from pydantic import Field
from pymongo import IndexModel

from app.models.plan import Branch, PlanNode, PlanToggles, SuccessLevels


class PlanVersion(Document):
    plan_id: PydanticObjectId
    user_id: PydanticObjectId
    version: int
    skill_name: str
    nodes_snapshot: list[PlanNode] = Field(default_factory=list)
    branches_snapshot: list[Branch] = Field(default_factory=list)
    active_branch_id: str
    success_levels: SuccessLevels = Field(default_factory=SuccessLevels)
    toggles: PlanToggles = Field(default_factory=PlanToggles)
    days_per_week: int
    minutes_per_day: int
    change_summary: str = ""
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime = Field(
        default_factory=lambda: datetime.utcnow() + timedelta(days=60)
    )

    class Settings:
        name = "plan_versions"
        indexes = [
            [("plan_id", 1), ("version", -1)],
            IndexModel([("expires_at", 1)], expireAfterSeconds=0),
        ]
