from datetime import date, datetime
from typing import Optional

from beanie import Document, Indexed
from pydantic import Field
from beanie import PydanticObjectId


class Streak(Document):
    user_id: Indexed(PydanticObjectId, unique=True)
    activity_dates: list[date] = Field(default_factory=list)
    current_streak: int = 0
    longest_streak: int = 0
    total_days_active: int = 0
    last_activity_date: Optional[date] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "streaks"
        indexes = ["last_activity_date"]
