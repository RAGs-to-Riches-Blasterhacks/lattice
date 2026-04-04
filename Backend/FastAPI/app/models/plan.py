from datetime import date, datetime
from enum import Enum
from typing import Optional
from uuid import uuid4

from beanie import Document, Indexed
from pydantic import BaseModel, Field
from beanie import PydanticObjectId


# --- Enums ---


class NodeStatus(str, Enum):
    not_started = "not_started"
    in_progress = "in_progress"
    completed = "completed"
    skipped = "skipped"


class PlanStatus(str, Enum):
    active = "active"
    paused = "paused"
    completed = "completed"
    abandoned = "abandoned"


class ResourceType(str, Enum):
    youtube = "youtube"
    article = "article"
    book = "book"
    exercise = "exercise"
    event = "event"


# --- Embedded sub-models ---


class Resource(BaseModel):
    type: ResourceType
    title: str
    url: str
    duration_minutes: Optional[int] = None
    is_optional: bool = False


class NodeOption(BaseModel):
    """Alternative approach within a node. NOT a branch — all options reach the same next node."""

    option_id: str = Field(default_factory=lambda: str(uuid4()))
    title: str
    description: str = ""
    resources: list[Resource] = Field(default_factory=list)
    is_selected: bool = False


class ActivityEntry(BaseModel):
    date: date
    note: Optional[str] = None


class NodeNote(BaseModel):
    content: str
    created_at: datetime = Field(default_factory=datetime.utcnow)


class PlanNode(BaseModel):
    node_id: str = Field(default_factory=lambda: str(uuid4()))
    branch_id: str
    node_number: int
    title: str
    description: str = ""
    skill_level: Optional[str] = None
    type_of_task: Optional[str] = None
    options: list[NodeOption] = Field(default_factory=list)
    resources: list[Resource] = Field(default_factory=list)
    status: NodeStatus = NodeStatus.not_started
    next_node_ids: list[str] = Field(default_factory=list)
    prev_node_id: Optional[str] = None
    scheduled_date: Optional[date] = None
    completed_at: Optional[datetime] = None
    notes: list[NodeNote] = Field(default_factory=list)
    activity_log: list[ActivityEntry] = Field(default_factory=list)
    needs_regeneration: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    regenerated_at: Optional[datetime] = None


class Branch(BaseModel):
    """Git ref equivalent — lightweight pointer to a sequence of nodes."""

    branch_id: str = Field(default_factory=lambda: str(uuid4()))
    name: str
    diverged_from_node_id: Optional[str] = None
    parent_branch_id: Optional[str] = None
    first_node_id: str
    tip_node_id: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    is_archived: bool = False


class PlanToggles(BaseModel):
    include_books: bool = False
    include_extra_homework: bool = False
    include_local_events: bool = False
    include_youtube: bool = True
    include_articles: bool = True


class SuccessLevels(BaseModel):
    should_know: list[str] = Field(default_factory=list)
    might_know: list[str] = Field(default_factory=list)
    should_know_next: list[str] = Field(default_factory=list)


# --- Top-level Document ---


class Plan(Document):
    user_id: Indexed(PydanticObjectId)
    skill_name: str
    description: Optional[str] = None
    success_levels: SuccessLevels = Field(default_factory=SuccessLevels)
    days_per_week: int
    minutes_per_day: int
    toggles: PlanToggles = Field(default_factory=PlanToggles)
    nodes: list[PlanNode] = Field(default_factory=list)
    branches: list[Branch] = Field(default_factory=list)
    active_branch_id: str
    status: PlanStatus = PlanStatus.active
    current_node_id: Optional[str] = None
    generation_version: int = 1
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    class Settings:
        name = "plans"
        indexes = [
            "user_id",
            [("user_id", 1), ("status", 1)],
            [("user_id", 1), ("skill_name", 1)],
        ]
