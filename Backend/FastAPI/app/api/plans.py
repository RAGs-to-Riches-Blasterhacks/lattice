from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import get_current_user
from app.models.plan import Plan, PlanStatus
from app.models.user import User
from app.schemas.plan import (
    ActivePathResponse,
    AddNoteRequest,
    BranchResponse,
    BranchSwitchRequest,
    LogProgressRequest,
    NodeEditRequest,
    PlanCreate,
    PlanResponse,
    PlanSummaryResponse,
    ProgressResponse,
)
from app.services import plan_service

router = APIRouter(prefix="/plans", tags=["plans"])


def _branch_response(b) -> BranchResponse:
    return BranchResponse(
        branch_id=b.branch_id,
        name=b.name,
        diverged_from_node_id=b.diverged_from_node_id,
        parent_branch_id=b.parent_branch_id,
        first_node_id=b.first_node_id,
        tip_node_id=b.tip_node_id,
        created_at=b.created_at,
        is_archived=b.is_archived,
    )


def _plan_response(plan: Plan) -> PlanResponse:
    return PlanResponse(
        id=str(plan.id),
        user_id=str(plan.user_id),
        skill_name=plan.skill_name,
        description=plan.description,
        success_levels=plan.success_levels,
        days_per_week=plan.days_per_week,
        minutes_per_day=plan.minutes_per_day,
        toggles=plan.toggles,
        nodes=plan.nodes,
        branches=[_branch_response(b) for b in plan.branches],
        active_branch_id=plan.active_branch_id,
        palette=plan.palette,
        status=plan.status,
        current_node_id=plan.current_node_id,
        generation_version=plan.generation_version,
        created_at=plan.created_at,
        updated_at=plan.updated_at,
        started_at=plan.started_at,
        completed_at=plan.completed_at,
    )


def _plan_summary(plan: Plan) -> PlanSummaryResponse:
    from app.models.plan import NodeStatus

    active_nodes = plan_service.get_active_path(plan)
    completed = sum(1 for n in active_nodes if n.status == NodeStatus.completed)

    current_title = None
    if plan.current_node_id:
        node = plan_service._find_node(plan, plan.current_node_id)
        if node:
            current_title = node.title
    if current_title is None and active_nodes:
        # Fall back to first non-completed node on the active path
        for n in active_nodes:
            if n.status != NodeStatus.completed:
                current_title = n.title
                break

    return PlanSummaryResponse(
        id=str(plan.id),
        skill_name=plan.skill_name,
        description=plan.description,
        status=plan.status,
        active_branch_id=plan.active_branch_id,
        branch_count=len(plan.branches),
        node_count=len(active_nodes),
        completed_node_count=completed,
        current_node_title=current_title,
        created_at=plan.created_at,
        updated_at=plan.updated_at,
    )


async def _get_user_plan(plan_id: str, user: User) -> Plan:
    """Fetch a plan and verify ownership."""
    plan = await Plan.get(plan_id)
    if plan is None or plan.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")
    return plan


@router.post("", response_model=PlanResponse, status_code=status.HTTP_201_CREATED)
async def create_plan(body: PlanCreate, user: User = Depends(get_current_user)):
    """Create a new learning plan. Nodes are empty until the LLM generates them."""
    from uuid import uuid4
    from app.models.plan import Branch

    main_branch_id = str(uuid4())
    plan = Plan(
        user_id=user.id,
        skill_name=body.skill_name,
        description=body.description,
        success_levels=body.success_levels,
        days_per_week=body.days_per_week,
        minutes_per_day=body.minutes_per_day,
        toggles=body.toggles,
        active_branch_id=main_branch_id,
        branches=[
            Branch(
                branch_id=main_branch_id,
                name="main",
                first_node_id="",
                tip_node_id="",
            )
        ],
    )
    await plan.insert()
    return _plan_response(plan)


@router.get("", response_model=list[PlanSummaryResponse])
async def list_plans(user: User = Depends(get_current_user)):
    """List all plans for the current user."""
    plans = await Plan.find(Plan.user_id == user.id).to_list()
    return [_plan_summary(p) for p in plans]


@router.get("/{plan_id}", response_model=PlanResponse)
async def get_plan(plan_id: str, user: User = Depends(get_current_user)):
    """Get a single plan with all nodes and branches."""
    plan = await _get_user_plan(plan_id, user)
    return _plan_response(plan)


@router.get("/{plan_id}/path", response_model=ActivePathResponse)
async def get_active_path(plan_id: str, user: User = Depends(get_current_user)):
    """Resolve the active branch's node sequence (including ancestor prefixes)."""
    plan = await _get_user_plan(plan_id, user)
    nodes = plan_service.get_active_path(plan)
    branch = plan_service._get_branch(plan, plan.active_branch_id)
    return ActivePathResponse(
        nodes=nodes,
        branch=_branch_response(branch),
    )


@router.patch("/{plan_id}/nodes/{node_id}", response_model=PlanResponse)
async def edit_node(
    plan_id: str,
    node_id: str,
    body: NodeEditRequest,
    user: User = Depends(get_current_user),
):
    """Edit a node. Core field changes trigger branching automatically."""
    plan = await _get_user_plan(plan_id, user)
    changes = body.model_dump(exclude_none=True)
    if not changes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="No changes provided"
        )

    try:
        plan, did_branch = plan_service.apply_node_edit(plan, node_id, changes)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    await plan.save()
    return _plan_response(plan)


@router.delete("/{plan_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plan(plan_id: str, user: User = Depends(get_current_user)):
    """Delete a plan regardless of its status."""
    plan = await _get_user_plan(plan_id, user)
    await plan.delete()
    return None


@router.post(
    "/{plan_id}/nodes/{node_id}/notes",
    response_model=PlanResponse,
)
async def add_note(
    plan_id: str,
    node_id: str,
    body: AddNoteRequest,
    user: User = Depends(get_current_user),
):
    """Add a note to a specific step."""
    from app.models.plan import NodeNote

    plan = await _get_user_plan(plan_id, user)
    node = plan_service._find_node(plan, node_id)
    if node is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Node not found"
        )
    node.notes.append(NodeNote(content=body.content))
    from datetime import datetime
    plan.updated_at = datetime.utcnow()
    await plan.save()
    return _plan_response(plan)


@router.post(
    "/{plan_id}/nodes/{node_id}/progress",
    response_model=ProgressResponse,
)
async def log_progress(
    plan_id: str,
    node_id: str,
    body: LogProgressRequest,
    user: User = Depends(get_current_user),
):
    """Log progress on a step: update its status and optionally add an activity entry."""
    from datetime import date as date_cls, datetime

    from app.models.plan import ActivityEntry, NodeStatus

    plan = await _get_user_plan(plan_id, user)
    node = plan_service._find_node(plan, node_id)
    if node is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Node not found"
        )

    node.status = body.status
    node.activity_log.append(
        ActivityEntry(date=date_cls.today(), note=body.note)
    )

    if body.status == NodeStatus.completed:
        node.completed_at = datetime.utcnow()

    # Auto-complete the plan when all active-branch nodes are done
    plan_completed = False
    if body.status == NodeStatus.completed:
        active_nodes = plan_service.get_active_path(plan)
        if active_nodes and all(
            n.status == NodeStatus.completed for n in active_nodes
        ):
            plan.status = PlanStatus.completed
            plan.completed_at = datetime.utcnow()
            plan_completed = True

    plan.updated_at = datetime.utcnow()
    await plan.save()
    return ProgressResponse(
        node_id=node_id,
        status=node.status,
        completed_at=node.completed_at,
        plan_completed=plan_completed,
    )


@router.post("/{plan_id}/switch-branch", response_model=PlanResponse)
async def switch_branch(
    plan_id: str,
    body: BranchSwitchRequest,
    user: User = Depends(get_current_user),
):
    """Switch the active branch."""
    plan = await _get_user_plan(plan_id, user)
    try:
        plan = plan_service.switch_branch(plan, body.branch_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    await plan.save()
    return _plan_response(plan)


