from collections import defaultdict
from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.security import get_current_user
from app.models.plan import NodeStatus, Plan, PlanStatus
from app.models.streak import Streak
from app.models.user import User
from app.schemas.streak import DailyTaskCount, StatsResponse, StreakResponse

router = APIRouter(prefix="/streaks", tags=["streaks"])


class CheckInRequest(BaseModel):
    plan_id: str
    node_id: str
    note: str | None = None


def _streak_response(streak: Streak) -> StreakResponse:
    return StreakResponse(
        user_id=str(streak.user_id),
        current_streak=streak.current_streak,
        longest_streak=streak.longest_streak,
        total_days_active=streak.total_days_active,
        last_activity_date=streak.last_activity_date,
        created_at=streak.created_at,
        updated_at=streak.updated_at,
    )


def _recompute_streak(activity_dates: list[date]) -> tuple[int, int]:
    """Walk backward through sorted dates to compute current and longest streaks."""
    if not activity_dates:
        return 0, 0

    unique = sorted(set(activity_dates), reverse=True)
    current = 1
    for i in range(1, len(unique)):
        if (unique[i - 1] - unique[i]).days == 1:
            current += 1
        else:
            break

    # Check if the streak is still active (last activity was today or yesterday)
    today = date.today()
    if unique[0] < today and (today - unique[0]).days > 1:
        current = 0

    longest = current
    run = 1
    for i in range(1, len(unique)):
        if (unique[i - 1] - unique[i]).days == 1:
            run += 1
            longest = max(longest, run)
        else:
            run = 1

    return current, longest


async def _get_or_create_streak(user: User) -> Streak:
    streak = await Streak.find_one(Streak.user_id == user.id)
    if streak is None:
        streak = Streak(user_id=user.id)
        await streak.insert()
    return streak


@router.get("/me", response_model=StreakResponse)
async def get_my_streak(user: User = Depends(get_current_user)):
    """Get the current user's streak stats."""
    streak = await _get_or_create_streak(user)
    return _streak_response(streak)


@router.get("/me/stats", response_model=StatsResponse)
async def get_my_stats(user: User = Depends(get_current_user)):
    """Aggregated stats: streak info, tasks/plans completed, and a 30-day
    tasks-completed-per-day breakdown."""
    streak = await _get_or_create_streak(user)
    plans = await Plan.find(Plan.user_id == user.id).to_list()

    cutoff = datetime.combine(date.today() - timedelta(days=29), datetime.min.time())
    total_tasks_completed = 0
    daily_counts: dict[date, int] = defaultdict(int)

    for plan in plans:
        for node in plan.nodes:
            if node.status == NodeStatus.completed and node.completed_at is not None:
                total_tasks_completed += 1
                if node.completed_at >= cutoff:
                    daily_counts[node.completed_at.date()] += 1

    total_plans_completed = sum(
        1 for p in plans if p.status == PlanStatus.completed
    )

    # Build the 30-day series (fill zeros for days with no completions)
    today = date.today()
    tasks_completed_by_day = [
        DailyTaskCount(date=today - timedelta(days=i), count=daily_counts.get(today - timedelta(days=i), 0))
        for i in range(29, -1, -1)
    ]

    return StatsResponse(
        current_streak=streak.current_streak,
        longest_streak=streak.longest_streak,
        total_days_active=streak.total_days_active,
        total_tasks_completed=total_tasks_completed,
        total_plans_completed=total_plans_completed,
        tasks_completed_by_day=tasks_completed_by_day,
    )


@router.post("/check-in", response_model=StreakResponse)
async def check_in(body: CheckInRequest, user: User = Depends(get_current_user)):
    """Log activity for today on a specific node. Updates both the node's
    activity_log and the user's global streak."""
    from app.models.plan import ActivityEntry

    # Validate plan ownership and find the node
    plan = await Plan.get(body.plan_id)
    if plan is None or plan.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")

    node = None
    for n in plan.nodes:
        if n.node_id == body.node_id:
            node = n
            break
    if node is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Node not found")

    today = date.today()

    # Update node activity log (skip if already checked in today)
    if not node.activity_log or node.activity_log[-1].date != today:
        node.activity_log.append(ActivityEntry(date=today, note=body.note))
        plan.updated_at = datetime.utcnow()
        await plan.save()

    # Update global streak
    streak = await _get_or_create_streak(user)
    if today not in streak.activity_dates:
        streak.activity_dates.append(today)

    streak.last_activity_date = today
    streak.total_days_active = len(set(streak.activity_dates))
    streak.current_streak, streak.longest_streak = _recompute_streak(
        streak.activity_dates
    )
    streak.updated_at = datetime.utcnow()
    await streak.save()

    return _streak_response(streak)
