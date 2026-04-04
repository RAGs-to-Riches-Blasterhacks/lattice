import random
import string
from datetime import datetime

from beanie import PydanticObjectId

from app.models.plan import NodeStatus, Plan, PlanStatus
from app.models.streak import Streak
from app.models.user import User
from app.services.plan_service import get_active_path


async def generate_friend_code() -> str:
    """Generate a unique LATTICE-XXXX friend code."""
    chars = string.ascii_uppercase + string.digits
    for _ in range(10):
        suffix = "".join(random.choices(chars, k=4))
        code = f"LATTICE-{suffix}"
        existing = await User.find_one(User.friend_code == code)
        if existing is None:
            return code
    raise RuntimeError("Failed to generate unique friend code after 10 attempts")


async def ensure_friend_code(user: User) -> str:
    """Return the user's friend code, generating one if needed."""
    if user.friend_code is not None:
        return user.friend_code
    code = await generate_friend_code()
    user.friend_code = code
    user.updated_at = datetime.utcnow()
    await user.save()
    return code


async def add_friend_by_code(current_user: User, friend_code: str) -> User:
    """Add a friend by their code. Returns the friend's User document."""
    code = friend_code.strip().upper()
    target = await User.find_one(User.friend_code == code)
    if target is None:
        raise ValueError("Invalid friend code")
    if target.id == current_user.id:
        raise ValueError("Cannot add yourself")
    if target.id in current_user.friends:
        raise ValueError("Already friends")

    # Atomic bidirectional add
    await User.find_one(User.id == current_user.id).update(
        {"$addToSet": {"friends": target.id}}
    )
    await User.find_one(User.id == target.id).update(
        {"$addToSet": {"friends": current_user.id}}
    )
    return target


async def remove_friend(current_user: User, friend_id: PydanticObjectId) -> None:
    """Remove a friend bidirectionally."""
    friend = await User.get(friend_id)
    if friend is None or friend_id not in current_user.friends:
        raise ValueError("Friend not found")

    await User.find_one(User.id == current_user.id).update(
        {"$pull": {"friends": friend_id}}
    )
    await User.find_one(User.id == friend.id).update(
        {"$pull": {"friends": current_user.id}}
    )


def _derive_plan_stats(plan: Plan | None) -> tuple[str, int, int]:
    """Derive current_task, completed_days, total_days from a plan."""
    if plan is None:
        return "No active plan", 0, 0

    # Get active path nodes
    try:
        path = get_active_path(plan)
    except Exception:
        path = plan.nodes

    total_days = len(path)
    completed_days = sum(
        1 for n in path if n.status in (NodeStatus.completed, NodeStatus.skipped)
    )

    # Current task: find current node, fall back to skill_name
    current_task = plan.skill_name
    if plan.current_node_id:
        for node in plan.nodes:
            if node.node_id == plan.current_node_id:
                current_task = node.title
                break

    return current_task, completed_days, total_days


async def get_friend_info(friend_user: User) -> dict:
    """Build friend info dict for a single user."""
    streak = await Streak.find_one(Streak.user_id == friend_user.id)
    plan = await Plan.find_one(
        Plan.user_id == friend_user.id, Plan.status == PlanStatus.active
    ).sort(-Plan.updated_at)

    current_task, completed_days, total_days = _derive_plan_stats(plan)
    handle = "@" + friend_user.display_name.lower().replace(" ", "")

    return {
        "user_id": str(friend_user.id),
        "name": friend_user.display_name,
        "handle": handle,
        "streak": streak.current_streak if streak else 0,
        "current_task": current_task,
        "completed_days": completed_days,
        "total_days": total_days,
    }


async def get_all_friends_info(current_user: User) -> list[dict]:
    """Batch-fetch all friends' info in 3 queries."""
    if not current_user.friends:
        return []

    friend_ids = current_user.friends

    # Batch queries
    friends = await User.find({"_id": {"$in": friend_ids}}).to_list()
    streaks = await Streak.find({"user_id": {"$in": friend_ids}}).to_list()
    plans = await Plan.find(
        {"user_id": {"$in": friend_ids}, "status": PlanStatus.active}
    ).sort(-Plan.updated_at).to_list()

    # Index by user_id
    streak_map = {s.user_id: s for s in streaks}
    plan_map: dict[PydanticObjectId, Plan] = {}
    for p in plans:
        if p.user_id not in plan_map:  # first = most recently updated
            plan_map[p.user_id] = p

    result = []
    for friend in friends:
        streak = streak_map.get(friend.id)
        plan = plan_map.get(friend.id)
        current_task, completed_days, total_days = _derive_plan_stats(plan)
        handle = "@" + friend.display_name.lower().replace(" ", "")

        result.append({
            "user_id": str(friend.id),
            "name": friend.display_name,
            "handle": handle,
            "streak": streak.current_streak if streak else 0,
            "current_task": current_task,
            "completed_days": completed_days,
            "total_days": total_days,
        })

    return result
