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


class DailyTaskCount(BaseModel):
    date: date
    count: int


class StatsResponse(BaseModel):
    current_streak: int
    longest_streak: int
    total_days_active: int
    total_tasks_completed: int
    total_plans_completed: int
    tasks_completed_by_day: list[DailyTaskCount]
