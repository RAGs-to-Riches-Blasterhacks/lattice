from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class StreakResponse(BaseModel):
    user_id: str
    current_streak: int
    longest_streak: int
    total_days_active: int
    last_activity_date: Optional[date] = None
    created_at: datetime
    updated_at: datetime
