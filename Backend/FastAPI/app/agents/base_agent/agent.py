import os

import litellm
litellm.suppress_debug_info = True

import httpx
from pydantic import BaseModel, Field
from google.adk.agents import LlmAgent
from google.adk.models.lite_llm import LiteLlm
from google.adk.tools import ToolContext

from app.models.plan import Palette, Resource, SuccessLevels

MODEL = LiteLlm(model="openai/gpt-5.4-mini")


# ---------------------------------------------------------------------------
# Output Schemas — lightweight versions for LLM output only
# (DB models like PlanNode have too many internal fields)
# ---------------------------------------------------------------------------


class NodeOptionOutput(BaseModel):
    title: str
    description: str = ""


class PlanNodeOutput(BaseModel):
    node_number: int
    title: str
    description: str = ""
    skill_level: str
    type_of_task: str
    options: list[NodeOptionOutput] = Field(default_factory=list)


class PlannerOutput(BaseModel):
    skill: str
    end_goal: str
    days_per_week: int
    minutes_per_day: int
    success_levels: SuccessLevels
    nodes: list[PlanNodeOutput]


class ResearcherOutput(BaseModel):
    task: str
    resources: list[Resource] = Field(default_factory=list)
    guide: str = ""

GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY", "")
GOOGLE_CSE_ID = os.environ.get("GOOGLE_CSE_ID", "")
EVENTBRITE_TOKEN = os.environ.get("EVENTBRITE_TOKEN", "")


# ---------------------------------------------------------------------------
# Planner Tools
# ---------------------------------------------------------------------------


def estimate_difficulty(skill: str) -> dict:
    """Estimate the difficulty level and average time-to-competency for a skill.

    Args:
        skill: The skill to evaluate (e.g. "Rust programming", "watercolor painting").

    Returns:
        A dict with difficulty rating, estimated hours, and reasoning.
        Replace this stub with a real skill-taxonomy or crowd-sourced data lookup.
    """
    return {
        "skill": skill,
        "difficulty": "intermediate",
        "estimated_hours_to_competency": 40,
        "reasoning": f"[stub] Default estimate for '{skill}'. Wire up a skill taxonomy API for real data.",
    }


def get_prerequisites(skill: str) -> dict:
    """Identify prerequisite skills or knowledge needed before starting a skill.

    Args:
        skill: The skill to find prerequisites for.

    Returns:
        A dict with a list of prerequisite skills and their importance.
        Replace this stub with a real knowledge-graph or curriculum API.
    """
    return {
        "skill": skill,
        "prerequisites": [
            {"name": f"[stub] Foundational concept for {skill}", "importance": "required"},
            {"name": f"[stub] Helpful background for {skill}", "importance": "recommended"},
        ],
        "note": "Stub — wire up a knowledge-graph or curriculum API for real results.",
    }


# ---------------------------------------------------------------------------
# Planner Agent
# ---------------------------------------------------------------------------

planner_agent = LlmAgent(
    model=MODEL,
    name="planner_agent",
    description="Creates a structured, personalized learning roadmap.",
    output_key="plan_result",
    output_schema=PlannerOutput,
    instruction="""You are a learning path designer. Given a skill, end goal, days_per_week, and minutes_per_day, design a 5-8 node roadmap.

Call estimate_difficulty and get_prerequisites first, then build the plan.

Rules:
- Start from basics, build progressively
- Each node fits within minutes_per_day
- Mix task types: reading, practice, project, review, exploration
- 2-3 options per node
- skill_level: beginner, intermediate, or advanced
- Write descriptions like a friend, not a textbook
- Write success_levels as things a real person would say""",
    tools=[estimate_difficulty, get_prerequisites],
)


# ---------------------------------------------------------------------------
# Researcher Tools
# ---------------------------------------------------------------------------


def find_youtube_videos(topic: str) -> dict:
    """Find YouTube videos for a learning topic using YouTube Data API v3.

    Args:
        topic: The topic or task to search videos for.

    Returns:
        A dict with Resource-shaped results (type="youtube").
    """
    try:
        resp = httpx.get(
            "https://www.googleapis.com/youtube/v3/search",
            params={
                "part": "snippet",
                "q": topic,
                "type": "video",
                "maxResults": 5,
                "order": "relevance",
                "key": GOOGLE_API_KEY,
            },
            timeout=10,
        )
        resp.raise_for_status()
        items = resp.json().get("items", [])
        resources = [
            {
                "type": "youtube",
                "title": item["snippet"]["title"],
                "url": f"https://youtube.com/watch?v={item['id']['videoId']}",
                "duration_minutes": None,
                "is_optional": i >= 3,
            }
            for i, item in enumerate(items)
            if item.get("id", {}).get("videoId")
        ]
        return {"resources": resources}
    except Exception as e:
        return {"resources": [], "error": str(e)}


def find_articles(topic: str) -> dict:
    """Find articles and documentation for a learning topic using Google Custom Search.

    Args:
        topic: The topic or task to search articles for.

    Returns:
        A dict with Resource-shaped results (type="article").
    """
    try:
        resp = httpx.get(
            "https://www.googleapis.com/customsearch/v1",
            params={
                "key": GOOGLE_API_KEY,
                "cx": GOOGLE_CSE_ID,
                "q": f"{topic} tutorial guide",
                "num": 5,
            },
            timeout=10,
        )
        resp.raise_for_status()
        items = resp.json().get("items", [])
        resources = [
            {
                "type": "article",
                "title": item["title"],
                "url": item["link"],
                "duration_minutes": None,
                "is_optional": i >= 3,
            }
            for i, item in enumerate(items)
        ]
        return {"resources": resources}
    except Exception as e:
        return {"resources": [], "error": str(e)}


def find_books(topic: str) -> dict:
    """Find books for a learning topic using Google Books API.

    Args:
        topic: The topic or task to search books for.

    Returns:
        A dict with Resource-shaped results (type="book").
    """
    try:
        resp = httpx.get(
            "https://www.googleapis.com/books/v1/volumes",
            params={
                "q": topic,
                "maxResults": 5,
                "key": GOOGLE_API_KEY,
            },
            timeout=10,
        )
        resp.raise_for_status()
        items = resp.json().get("items", [])
        resources = [
            {
                "type": "book",
                "title": item["volumeInfo"].get("title", "Unknown Title"),
                "url": item["volumeInfo"].get("infoLink", ""),
                "duration_minutes": None,
                "is_optional": i >= 2,
            }
            for i, item in enumerate(items)
            if "volumeInfo" in item
        ]
        return {"resources": resources}
    except Exception as e:
        return {"resources": [], "error": str(e)}


def _extract_eventbrite_id(url: str) -> str | None:
    """Extract the event ID from an Eventbrite URL (the trailing numeric segment)."""
    import re
    match = re.search(r"eventbrite\.com/e/[^/]+-(\d+)", url)
    return match.group(1) if match else None


def _get_eventbrite_details(event_id: str) -> dict | None:
    """Fetch structured event details from Eventbrite's API v3."""
    try:
        resp = httpx.get(
            f"https://www.eventbriteapi.com/v3/events/{event_id}/",
            params={"expand": "venue"},
            headers={"Authorization": f"Bearer {EVENTBRITE_TOKEN}"},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()

        venue = data.get("venue", {})
        address = venue.get("address", {})
        start = data.get("start", {})

        return {
            "title": data.get("name", {}).get("text", ""),
            "description": data.get("description", {}).get("text", ""),
            "url": data.get("url", ""),
            "start_date": start.get("local"),
            "venue_name": venue.get("name"),
            "venue_address": address.get("localized_address_display"),
            "is_free": data.get("is_free", False),
        }
    except Exception:
        return None


def find_local_events(topic: str, city: str, state: str, country: str) -> dict:
    """Find local events for a learning topic.

    Args:
        topic: The topic or skill to find events for.
        city: The user's city.
        state: The user's state or region.
        country: The user's country.

    Returns:
        A dict with Resource-shaped results (type="event").
    """
    location = " ".join(filter(None, [city, state, country]))
    resources = []

    try:
        resp = httpx.get(
            "https://www.googleapis.com/customsearch/v1",
            params={
                "key": GOOGLE_API_KEY,
                "cx": GOOGLE_CSE_ID,
                "q": f"site:eventbrite.com {topic} {location}",
                "num": 5,
            },
            timeout=10,
        )
        resp.raise_for_status()
        search_items = resp.json().get("items", [])
    except Exception as e:
        return {"resources": [], "error": f"Google search failed: {e}"}

    for item in search_items:
        url = item.get("link", "")
        event_id = _extract_eventbrite_id(url)

        if event_id and EVENTBRITE_TOKEN:
            details = _get_eventbrite_details(event_id)
            if details:
                resources.append({
                    "type": "event",
                    "title": details["title"] or item.get("title", ""),
                    "url": details["url"] or url,
                    "duration_minutes": None,
                    "is_optional": True,
                    "event_details": {
                        "start_date": details["start_date"],
                        "venue_name": details["venue_name"],
                        "venue_address": details["venue_address"],
                        "is_free": details["is_free"],
                        "description": details["description"][:200] if details["description"] else None,
                    },
                })
                continue

        resources.append({
            "type": "event",
            "title": item.get("title", ""),
            "url": url,
            "duration_minutes": None,
            "is_optional": True,
        })

    return {"resources": resources}


# ---------------------------------------------------------------------------
# Researcher Agent
# ---------------------------------------------------------------------------

researcher_agent = LlmAgent(
    model=MODEL,
    name="researcher_agent",
    description="Finds learning resources for a specific task.",
    output_key="research_result",
    output_schema=ResearcherOutput,
    instruction="""You are a resource curator. Given a task title/description and toggles, call the matching tools:
- include_youtube=true → find_youtube_videos
- include_articles=true → find_articles
- include_books=true → find_books
- include_local_events=true → find_local_events

If include_extra_homework=true, add 2-3 hands-on exercises (type="exercise", url="").
Write a 3-5 sentence friendly guide for approaching this task.""",
    tools=[find_youtube_videos, find_articles, find_books, find_local_events],
)


# ---------------------------------------------------------------------------
# UI Color Agent
# ---------------------------------------------------------------------------


def check_contrast_ratio(hex_color_1: str, hex_color_2: str) -> dict:
    """Check the WCAG contrast ratio between two hex colors.

    Args:
        hex_color_1: First hex color (e.g. "#FFFFFF").
        hex_color_2: Second hex color (e.g. "#000000").

    Returns:
        A dict with the contrast ratio and WCAG compliance levels.
    """
    def _hex_to_luminance(hex_color: str) -> float:
        hex_color = hex_color.lstrip("#")
        r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
        components = []
        for c in (r, g, b):
            s = c / 255.0
            components.append(s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4)
        return 0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2]

    l1 = _hex_to_luminance(hex_color_1)
    l2 = _hex_to_luminance(hex_color_2)
    lighter, darker = max(l1, l2), min(l1, l2)
    ratio = (lighter + 0.05) / (darker + 0.05)

    return {
        "hex_color_1": hex_color_1,
        "hex_color_2": hex_color_2,
        "contrast_ratio": round(ratio, 2),
        "wcag_aa_normal_text": ratio >= 4.5,
        "wcag_aa_large_text": ratio >= 3.0,
        "wcag_aaa_normal_text": ratio >= 7.0,
    }


ui_agent = LlmAgent(
    model=MODEL,
    name="ui_agent",
    description="Creates an accessible color palette for a learning skill.",
    output_key="palette_result",
    output_schema=Palette,
    instruction="""Pick 5 colors (primary, secondary, accent, background, text) that match the vibe of the skill.
Use check_contrast_ratio to verify text on background (>=4.5) and primary on background (>=3.0).
Give each color a short name and rationale.""",
    tools=[check_contrast_ratio],
)


# ---------------------------------------------------------------------------
# Plan Persistence Tool
# ---------------------------------------------------------------------------


async def persist_plan(state: dict) -> dict:
    """Core plan persistence logic — callable from both the ADK tool and the safety net.

    Reads plan_result and palette_result from the provided state dict.

    Returns:
        A dict with plan_id, node_count, and status confirming the save,
        or an error dict if something went wrong.
    """
    import json as _json
    from datetime import datetime
    from uuid import uuid4

    from beanie import PydanticObjectId

    from app.models.plan import (
        Branch,
        NodeOption,
        Palette,
        PaletteColor,
        Plan,
        PlanNode,
        Resource,
        ResourceType,
        SuccessLevels,
    )
    from app.models.conversation import Conversation

    plan_id = state.get("plan_id")
    user_id = state.get("user_id")

    if not user_id:
        return {"error": "Missing user_id in session state."}

    # Read sub-agent results from state
    plan_raw = state.get("plan_result", "")
    palette_raw = state.get("palette_result", "")

    try:
        plan_data = _json.loads(plan_raw) if isinstance(plan_raw, str) else plan_raw
    except (_json.JSONDecodeError, TypeError):
        return {"error": "planner_agent did not produce valid JSON in plan_result."}

    if not plan_data or not isinstance(plan_data, dict):
        return {"error": "No plan data found. Transfer to planner_agent first."}

    palette_data = None
    try:
        palette_data = _json.loads(palette_raw) if isinstance(palette_raw, str) else palette_raw
    except (_json.JSONDecodeError, TypeError):
        pass  # palette is optional

    days_per_week = plan_data.get("days_per_week", 3)
    minutes_per_day = plan_data.get("minutes_per_day", 20)

    # --- Load or create plan -------------------------------------------
    plan: Plan | None = None
    if plan_id:
        plan = await Plan.get(plan_id)

    if plan is None:
        main_branch_id = str(uuid4())
        plan = Plan(
            user_id=PydanticObjectId(user_id),
            skill_name=plan_data.get("skill", ""),
            description=plan_data.get("end_goal"),
            days_per_week=days_per_week,
            minutes_per_day=minutes_per_day,
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
        plan_id = str(plan.id)
        state["plan_id"] = plan_id

        # Link to conversation
        conv_id = state.get("conv_id")
        if conv_id:
            conv = await Conversation.get(conv_id)
            if conv and conv.plan_id is None:
                conv.plan_id = plan.id
                await conv.save()

    branch_id = plan.active_branch_id

    # --- Build nodes ---------------------------------------------------
    nodes: list[PlanNode] = []
    for i, nd in enumerate(plan_data.get("nodes", [])):
        node_id = str(uuid4())

        options = [
            NodeOption(title=o["title"], description=o.get("description", ""))
            for o in nd.get("options", [])
        ]

        valid_types = {e.value for e in ResourceType}
        resources = [
            Resource(
                type=r["type"] if r.get("type") in valid_types else "article",
                title=r["title"],
                url=r.get("url", ""),
                duration_minutes=r.get("duration_minutes"),
                is_optional=r.get("is_optional", False),
            )
            for r in nd.get("resources", [])
        ]

        node = PlanNode(
            node_id=node_id,
            branch_id=branch_id,
            node_number=nd.get("node_number", i + 1),
            title=nd["title"],
            description=nd.get("description", ""),
            skill_level=nd.get("skill_level"),
            type_of_task=nd.get("type_of_task"),
            options=options,
            resources=resources,
            prev_node_id=nodes[-1].node_id if nodes else None,
        )
        if nodes:
            nodes[-1].next_node_ids = [node_id]
        nodes.append(node)

    # Update branch pointers
    if nodes:
        for b in plan.branches:
            if b.branch_id == branch_id:
                b.first_node_id = nodes[0].node_id
                b.tip_node_id = nodes[-1].node_id
                break

    # --- Palette -------------------------------------------------------
    if palette_data and isinstance(palette_data, dict):
        colors_list = palette_data.get("colors", palette_data.get("palette", []))
        plan.palette = Palette(
            theme=palette_data.get("theme", ""),
            colors=[
                PaletteColor(
                    role=c["role"],
                    hex=c["hex"],
                    name=c.get("name", ""),
                    rationale=c.get("rationale", ""),
                )
                for c in colors_list
                if isinstance(c, dict)
            ],
            accessibility=palette_data.get("accessibility"),
        )
    elif plan.palette is None:
        # Default palette when ui_agent didn't run
        plan.palette = Palette(
            theme="default",
            colors=[
                PaletteColor(role="primary", hex="#4F46E5", name="Indigo", rationale="Calm, focused energy"),
                PaletteColor(role="secondary", hex="#7C3AED", name="Violet", rationale="Creative complement"),
                PaletteColor(role="accent", hex="#F59E0B", name="Amber", rationale="Warm highlight for progress"),
                PaletteColor(role="background", hex="#F9FAFB", name="Cloud", rationale="Clean, easy on the eyes"),
                PaletteColor(role="text", hex="#111827", name="Ink", rationale="Strong readability"),
            ],
        )

    # --- Persist -------------------------------------------------------
    plan.nodes = nodes
    plan.skill_name = plan_data.get("skill", plan.skill_name)
    plan.description = plan_data.get("end_goal", plan.description)
    plan.days_per_week = days_per_week
    plan.minutes_per_day = minutes_per_day
    plan.success_levels = SuccessLevels(
        should_know=plan_data.get("success_levels", {}).get("should_know", []),
        might_know=plan_data.get("success_levels", {}).get("might_know", []),
        should_know_next=plan_data.get("success_levels", {}).get("should_know_next", []),
    )
    plan.current_node_id = nodes[0].node_id if nodes else None
    plan.updated_at = datetime.utcnow()
    await plan.save()

    # Clear consumed results so the safety net doesn't re-trigger
    state["plan_result"] = None
    state["palette_result"] = None

    return {
        "status": "saved",
        "plan_id": str(plan.id),
        "node_count": len(nodes),
        "has_palette": plan.palette is not None,
    }


async def save_complete_plan(tool_context: ToolContext) -> dict:
    """Save the learning plan to the database.

    Reads plan_result and palette_result from session state (set automatically
    by planner_agent and ui_agent).  No arguments needed — just call this tool
    after the sub-agents have finished.

    Returns:
        A dict with plan_id and node_count confirming the save.
    """
    result = await persist_plan(tool_context.state)
    return result


# ---------------------------------------------------------------------------
# Root Orchestrator
# ---------------------------------------------------------------------------

root_agent = LlmAgent(
    model=MODEL,
    name="root_agent",
    description="Lattice learning companion — chats with users and builds personalized learning plans.",
    instruction="""You are Lattice, a friendly learning companion.

## User context
Name: {user_name} | Timezone: {user_timezone} | Location: {user_city}, {user_state}, {user_country}

## Critical workflow (follow these steps IN ORDER):
1. Chat naturally to learn what skill they want, their goal, and how much time they have (days_per_week, minutes_per_day). Ask ONE question at a time.
2. Once you have enough info, transfer to planner_agent. It will store structured plan data in session state automatically.
3. Transfer to ui_agent with the skill name. It will store a color palette in session state automatically.
4. You MUST call the save_complete_plan tool. This is REQUIRED — do NOT skip this step. The tool reads from session state, you do not need to pass arguments.
5. After save_complete_plan succeeds, reply to the user with a short, excited summary of what they'll learn. Mention a few highlights from the roadmap.

## Rules
- NEVER output JSON, structured data, or raw tool results to the user. Your responses must always be natural language.
- ALWAYS call save_complete_plan after the sub-agents finish. The plan is NOT saved until you call this tool.
- Be warm and casual. Short responses. Match the user's energy.
- Don't ask about resource preferences or location unless they bring it up.
""",
    tools=[save_complete_plan],
    sub_agents=[planner_agent, researcher_agent, ui_agent],
)
