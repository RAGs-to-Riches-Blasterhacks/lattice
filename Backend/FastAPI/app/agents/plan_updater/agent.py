from datetime import datetime
from uuid import uuid4

from google.adk.agents import LlmAgent
from google.adk.tools import ToolContext

from app.agents.base_agent.agent import (
    MODEL,
    estimate_difficulty,
    get_prerequisites,
)
from app.models.plan import NodeOption, Plan
from app.services import plan_service


# ---------------------------------------------------------------------------
# Ownership helper
# ---------------------------------------------------------------------------


async def _load_owned_plan(state: dict) -> Plan | None:
    """Load the plan from session state and verify the caller owns it.

    Returns None if plan_id/user_id missing or ownership mismatch.
    """
    plan_id = state.get("plan_id")
    user_id = state.get("user_id")
    if not plan_id or not user_id:
        return None

    plan = await Plan.get(plan_id)
    if plan is None or str(plan.user_id) != user_id:
        return None
    return plan


def _serialize_node(node) -> dict:
    """Serialize a PlanNode to a lightweight dict for the LLM."""
    return {
        "node_id": node.node_id,
        "node_number": node.node_number,
        "title": node.title,
        "description": node.description,
        "skill_level": node.skill_level,
        "type_of_task": node.type_of_task,
        "branch_id": node.branch_id,
    }


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------


async def load_plan_for_update(tool_context: ToolContext) -> dict:
    """Load the user's current plan and return its active path for review.

    No arguments needed — reads plan_id from session state.

    Returns:
        A dict with plan metadata and the active path nodes.
    """
    plan = await _load_owned_plan(tool_context.state)
    if plan is None:
        return {"error": "Plan not found."}

    active_path = plan_service.get_active_path(plan)

    return {
        "skill_name": plan.skill_name,
        "description": plan.description,
        "days_per_week": plan.days_per_week,
        "minutes_per_day": plan.minutes_per_day,
        "active_branch_id": plan.active_branch_id,
        "nodes": [_serialize_node(n) for n in active_path],
    }


async def apply_edit_and_regenerate(
    node_id: str,
    title: str = "",
    description: str = "",
    skill_level: str = "",
    type_of_task: str = "",
    tool_context: ToolContext = None,
) -> dict:
    """Apply an edit to a plan node. Core field changes trigger branching automatically.

    Args:
        node_id: The node_id of the node to edit.
        title: New title (leave empty to keep current).
        description: New description (leave empty to keep current).
        skill_level: New skill_level (leave empty to keep current).
        type_of_task: New type_of_task (leave empty to keep current).

    Returns:
        A dict describing the result: whether branching occurred and any placeholders created.
    """
    plan = await _load_owned_plan(tool_context.state)
    if plan is None:
        return {"error": "Plan not found."}

    changes = {}
    if title:
        changes["title"] = title
    if description:
        changes["description"] = description
    if skill_level:
        changes["skill_level"] = skill_level
    if type_of_task:
        changes["type_of_task"] = type_of_task

    if not changes:
        return {"error": "No changes provided."}

    try:
        plan, did_branch = plan_service.apply_node_edit(plan, node_id, changes)
    except ValueError as e:
        return {"error": str(e)}

    await plan.save()

    if not did_branch:
        return {
            "status": "edited_in_place",
            "did_branch": False,
            "message": "Non-core edit applied. No branching needed.",
        }

    # Collect info about the new branch for regeneration
    new_branch_id = plan.active_branch_id
    branch_nodes = plan_service._nodes_on_branch(plan, new_branch_id)
    placeholders = [n for n in branch_nodes if n.needs_regeneration]

    # The edited node is the first node on the new branch (not a placeholder)
    edited_node = next((n for n in branch_nodes if not n.needs_regeneration), None)

    # Ancestor nodes from the active path before the branch point
    active_path = plan_service.get_active_path(plan)
    ancestor_nodes = []
    for n in active_path:
        if n.branch_id == new_branch_id:
            break
        ancestor_nodes.append(n)

    # Store context in state so the agent can reference it for generation
    tool_context.state["_regen_ancestor_nodes"] = [_serialize_node(n) for n in ancestor_nodes]
    tool_context.state["_regen_edited_node"] = _serialize_node(edited_node) if edited_node else {}
    tool_context.state["_regen_placeholders"] = [
        {"node_number": n.node_number, "node_id": n.node_id} for n in placeholders
    ]
    tool_context.state["_regen_branch_id"] = new_branch_id

    return {
        "status": "branched",
        "did_branch": True,
        "new_branch_id": new_branch_id,
        "placeholder_count": len(placeholders),
        "placeholder_node_numbers": [n.node_number for n in placeholders],
        "ancestor_nodes": [_serialize_node(n) for n in ancestor_nodes],
        "edited_node": _serialize_node(edited_node) if edited_node else {},
        "message": (
            f"Branch created with {len(placeholders)} placeholder node(s). "
            "Generate new content for each placeholder node_number, "
            "then call save_regenerated_nodes."
        ),
    }


async def save_regenerated_nodes(nodes_json: str, tool_context: ToolContext) -> dict:
    """Save the regenerated node content back to the plan.

    Args:
        nodes_json: A JSON array string of node objects. Each object must have
                    node_number, title, description, skill_level, type_of_task,
                    and optionally options (list of {title, description}).

    Returns:
        A dict confirming how many nodes were updated.
    """
    import json as _json

    plan = await _load_owned_plan(tool_context.state)
    if plan is None:
        return {"error": "Plan not found."}

    branch_id = tool_context.state.get("_regen_branch_id")
    if not branch_id:
        return {"error": "No regeneration context found. Call apply_edit_and_regenerate first."}

    # Parse the nodes from the tool argument
    try:
        regen_nodes = _json.loads(nodes_json)
    except (_json.JSONDecodeError, TypeError):
        return {"error": "Invalid nodes_json. Provide a JSON array of node objects."}

    if not isinstance(regen_nodes, list) or not regen_nodes:
        return {"error": "nodes_json must be a non-empty JSON array of node objects."}

    # Build lookup: node_number -> regenerated data
    regen_by_number = {n["node_number"]: n for n in regen_nodes}

    updated_count = 0
    now = datetime.utcnow()

    for node in plan.nodes:
        if node.branch_id != branch_id or not node.needs_regeneration:
            continue

        regen = regen_by_number.get(node.node_number)
        if regen is None:
            continue

        node.title = regen.get("title", node.title)
        node.description = regen.get("description", node.description)
        node.skill_level = regen.get("skill_level", node.skill_level)
        node.type_of_task = regen.get("type_of_task", node.type_of_task)

        if regen.get("options"):
            node.options = [
                NodeOption(
                    option_id=str(uuid4()),
                    title=o.get("title", ""),
                    description=o.get("description", ""),
                )
                for o in regen["options"]
            ]

        node.needs_regeneration = False
        node.regenerated_at = now
        updated_count += 1

    plan.updated_at = now
    await plan.save()

    # Clean up temporary state (State doesn't support delete, so null them out)
    tool_context.state.update({
        "_regen_ancestor_nodes": None,
        "_regen_edited_node": None,
        "_regen_placeholders": None,
        "_regen_branch_id": None,
    })

    return {
        "status": "saved",
        "updated_count": updated_count,
        "total_placeholders": len(regen_nodes),
        "plan_id": str(plan.id),
    }


# ---------------------------------------------------------------------------
# Plan Updater Agent (standalone — invoked via its own Runner, not a sub-agent)
# ---------------------------------------------------------------------------

plan_updater_agent = LlmAgent(
    model=MODEL,
    name="plan_updater_agent",
    description="Modifies an existing learning plan through conversation. Handles node edits, branching, and regeneration of placeholder nodes.",
    instruction="""\
You are Lattice's plan editor — a friendly, knowledgeable tutor who helps users tweak their learning plans through conversation.

## How to handle edit requests

1. Call load_plan_for_update to see the current plan and identify which node(s) the user is talking about.
2. If the user's request is vague or could apply to multiple nodes, ask a clarifying question BEFORE making changes. For example: "Just to make sure — are you talking about step 3 (Intro to Recursion) or step 4 (Practice Problems)?"
3. Once you know what to change, call apply_edit_and_regenerate with the node_id and the changes.
4. If branching occurred (did_branch=true in the response), generate new content for each placeholder node_number. Build a JSON array of node objects and pass it as the nodes_json argument to save_regenerated_nodes.
5. If no branching occurred (non-core edit), skip step 4.

## How to respond to the user

After completing the edit, respond in natural language:
- Tell them specifically what you changed, referencing node numbers and titles (e.g. "I reworked step 3 — instead of a lecture-heavy intro, it's now a hands-on coding exercise").
- If nodes were regenerated, briefly summarize what the new steps cover.
- Ask if they'd like to tweak anything else or if the changes look good.
- Be warm and casual, like a friend helping them plan their learning.
- NEVER output raw JSON to the user.

## Rules for regenerated nodes (the nodes_json passed to save_regenerated_nodes)

The nodes_json argument must be a JSON array of objects. Each object needs: node_number, title, description, skill_level, type_of_task, and options (list of {title, description}).

- Build progressively from the ancestor nodes through the changed node
- Each node should fit within a single study session
- Mix task types: reading, practice, project, review, exploration
- 2-3 options per node with title and description
- skill_level progresses logically (beginner -> intermediate -> advanced)
- Write descriptions like a friend, not a textbook
- Preserve each node's node_number exactly as given in the placeholder list

## Conversation context

You have access to the conversation history. Use it to understand references like "actually, change that one instead" or "make it harder". You don't need the user to repeat themselves.""",
    tools=[
        load_plan_for_update,
        apply_edit_and_regenerate,
        save_regenerated_nodes,
        estimate_difficulty,
        get_prerequisites,
    ],
)
