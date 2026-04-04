from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.plan import (
    Branch,
    NodeOption,
    NodeStatus,
    Palette,
    PlanNode,
    PlanStatus,
    PlanToggles,
    Resource,
    SuccessLevels,
)


# --- Requests ---


class PlanCreate(BaseModel):
    skill_name: str
    description: Optional[str] = None
    success_levels: SuccessLevels
    days_per_week: int
    minutes_per_day: int
    toggles: PlanToggles = PlanToggles()


class NodeEditRequest(BaseModel):
    """Edit a node. If any core field is changed, triggers branching."""

    title: Optional[str] = None
    description: Optional[str] = None
    skill_level: Optional[str] = None
    type_of_task: Optional[str] = None
    options: Optional[list[NodeOption]] = None
    resources: Optional[list[Resource]] = None
    status: Optional[NodeStatus] = None
    notes_to_add: Optional[str] = None
    scheduled_date: Optional[str] = None


class AddNoteRequest(BaseModel):
    content: str


class LogProgressRequest(BaseModel):
    """Mark a node's status and optionally log an activity entry."""
    status: NodeStatus
    note: Optional[str] = None


class BranchSwitchRequest(BaseModel):
    branch_id: str


# --- Responses ---


class BranchResponse(BaseModel):
    branch_id: str
    name: str
    diverged_from_node_id: Optional[str] = None
    parent_branch_id: Optional[str] = None
    first_node_id: str
    tip_node_id: str
    created_at: datetime
    is_archived: bool


class ActivePathResponse(BaseModel):
    nodes: list[PlanNode]
    branch: BranchResponse


class PlanResponse(BaseModel):
    id: str
    user_id: str
    skill_name: str
    description: Optional[str] = None
    success_levels: SuccessLevels
    days_per_week: int
    minutes_per_day: int
    toggles: PlanToggles
    nodes: list[PlanNode]
    branches: list[BranchResponse]
    active_branch_id: str
    palette: Optional[Palette] = None
    status: PlanStatus
    current_node_id: Optional[str] = None
    generation_version: int
    created_at: datetime
    updated_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None


class ProgressResponse(BaseModel):
    node_id: str
    status: NodeStatus
    completed_at: Optional[datetime] = None
    plan_completed: bool


class PlanSummaryResponse(BaseModel):
    id: str
    skill_name: str
    description: Optional[str] = None
    status: PlanStatus
    active_branch_id: str
    branch_count: int
    node_count: int
    created_at: datetime
    updated_at: datetime
