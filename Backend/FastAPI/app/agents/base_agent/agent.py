import os

import litellm
litellm.suppress_debug_info = True

import httpx
from pydantic import BaseModel, ConfigDict, Field
from google.adk.agents import LlmAgent
from google.adk.models.lite_llm import LiteLlm
from google.adk.tools import ToolContext


MODEL = LiteLlm(model="openai/gpt-5.4-mini")


# ---------------------------------------------------------------------------
# Output Schemas — lightweight versions for LLM output only
# (DB models like PlanNode have too many internal fields)
# ---------------------------------------------------------------------------


class NodeOptionOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str
    description: str = ""


class ResourceOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    type: str
    title: str
    url: str = ""
    duration_minutes: int = 0
    is_optional: bool = False


class PlanNodeOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    node_number: int
    title: str
    description: str = ""
    skill_level: str
    type_of_task: str
    options: list[NodeOptionOutput] = Field(default_factory=list)
    resources: list[ResourceOutput] = Field(default_factory=list)


class SuccessLevelsOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    should_know: list[str] = Field(default_factory=list)
    might_know: list[str] = Field(default_factory=list)
    should_know_next: list[str] = Field(default_factory=list)


# --- Palette output schema (OpenAI structured outputs needs additionalProperties: false) ---


class ContrastCheckOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    pair: str = ""
    contrast_ratio: float = 0.0
    meets_aa: bool = False
    meets_aaa: bool = False


class PaletteAccessibilityOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    checks: list[ContrastCheckOutput] = Field(default_factory=list)
    notes: str = ""


class PaletteColorOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    role: str
    hex: str
    name: str
    rationale: str = ""


class PaletteOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    theme: str = ""
    colors: list[PaletteColorOutput] = Field(default_factory=list)
    accessibility: PaletteAccessibilityOutput = Field(default_factory=PaletteAccessibilityOutput)


# --- Plan + Palette combined output ---


class PlannerOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    skill: str
    end_goal: str
    days_per_week: int
    minutes_per_day: int
    success_levels: SuccessLevelsOutput
    nodes: list[PlanNodeOutput]
    palette: PaletteOutput = Field(default_factory=PaletteOutput)


class ResearcherOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    task: str
    resources: list[ResourceOutput] = Field(default_factory=list)
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
    description="Creates a structured, personalized learning roadmap with a matching color palette.",
    output_key="plan_result",
    output_schema=PlannerOutput,
    instruction="""You are a learning path designer. Given a skill, end goal, days_per_week, and minutes_per_day, design a 5-30 node roadmap AND a color palette that matches the skill's vibe.

Call estimate_difficulty and get_prerequisites first, then build the plan.

## Scope & safety

You ONLY design learning plans for legitimate skills. You MUST refuse and return an error for:
- NSFW content, illegal activities (weapons, explosives, drugs, hacking for malicious purposes), or anything harmful
- Skills that are just vehicles for prohibited content
If the request is out of scope, respond with: {"error": "This skill is outside what Lattice can help with."}

## Philosophy — challenge, don't coddle

The user may not know much yet but don't create a baby plan for them. Users don't want to be treated like they're helpless. Instead, find the best advice from how real practitioners actually learned the skill and build a path that respects the user's intelligence.

- Get them doing real work early. If someone wants to learn guitar, they should be playing something by step 2, not reading music theory for a week.
- Push users to apply what they learn. Prefer hands-on projects and practice over passive consumption.
- Don't pad plans with fluff like "watch an overview" or "read the Wikipedia page" — every step should move them forward.
- When in doubt, make it slightly harder than you think they need. People rise to expectations.
- Give advice grounded in how people actually learn the skill well, not generic study tips.
- If you don't have enough info, make reasonable assumptions based on the skill and design a plan for that.

Rules:
- Design 5 to 30 nodes depending on the complexity of the skill — don't artificially compress a hard topic into 5 steps or stretch a simple one to 30
- Start from basics if the user doesn't know their current level, but include advanced nodes to stretch them
- Each node fits within minutes_per_day
- Mix task types but lean toward practice, projects, and exploration over passive reading
- 1 to 3 options per node, or no options at all — options are completely optional. When included, they should represent meaningfully different approaches (e.g. "build a CLI tool" vs "build a web app"), not just difficulty levels
- skill_level: beginner, intermediate, or advanced
- Write descriptions like a knowledgeable friend who's done this before, not a textbook
- Write success_levels as things a real person would say
- Each step should leave the user with something tangible they built, solved, or can demonstrate

Resources per node:
- Add 2-5 resources per node with real, specific recommendations
- type must be one of: youtube, article, book, exercise, event
- For youtube/article/book: include a specific, real title. Include the URL if you know it, otherwise leave url as empty string
- For exercise: describe a concrete hands-on practice task in the title (url can be empty string)
- Mix resource types across nodes — don't just list articles for every node
- duration_minutes: estimate how long the resource takes to consume (0 if unknown)
- is_optional: mark supplementary resources as true, core ones as false

Palette rules:
- Pick 5 colors: primary, secondary, accent, background, text
- Colors should match the vibe/energy of the skill being learned
- Ensure text on background has contrast ratio >= 4.5
- Ensure primary on background has contrast ratio >= 3.0
- Give each color a short name and rationale""",
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

## User context
Location: {user_city?}, {user_state?}, {user_country?} | Location opted in: {user_location_opted_in?}

When include_local_events=true and the user has opted in to location (user_location_opted_in is "True"), pass their city, state, and country to find_local_events. If user_location_opted_in is not "True" or the location values are "unknown", skip find_local_events.

If include_extra_homework=true, add 2-3 hands-on exercises (type="exercise", url="").
Write a 3-5 sentence friendly guide for approaching this task.""",
    tools=[find_youtube_videos, find_articles, find_books, find_local_events],
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

    # Read planner result from state (palette is now nested inside plan_result)
    plan_raw = state.get("plan_result", "")

    try:
        plan_data = _json.loads(plan_raw) if isinstance(plan_raw, str) else plan_raw
    except (_json.JSONDecodeError, TypeError):
        return {"error": "planner_agent did not produce valid JSON in plan_result."}

    if not plan_data or not isinstance(plan_data, dict):
        return {"error": "No plan data found. Transfer to planner_agent first."}

    # Palette lives inside plan_data now, fall back to legacy palette_result key
    palette_data = plan_data.get("palette") or state.get("palette_result")
    if isinstance(palette_data, str):
        try:
            palette_data = _json.loads(palette_data)
        except (_json.JSONDecodeError, TypeError):
            palette_data = None

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
    if nodes:
        nodes[0].status = "in_progress"
    plan.updated_at = datetime.utcnow()
    await plan.save()

    # Clear consumed results so the safety net doesn't re-trigger
    state["plan_result"] = None

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
Name: {user_name?} | Timezone: {user_timezone?} | Location: {user_city?}, {user_state?}, {user_country?}

## Scope & safety
You are ONLY a learning plan companion. You help users figure out what they want to learn and build a plan for it.

- You MUST refuse any request not related to skill-building or learning plans. Politely redirect: "I'm all about helping you learn new things — what skill are you interested in picking up?"
- You MUST refuse requests involving NSFW content, illegal activities (weapons, explosives, drugs, hacking for malicious purposes), or anything harmful. Say something like: "That's not something I can help with. What's something you've been wanting to learn?"
- Do NOT roleplay, generate creative fiction, answer general trivia, or act as a general-purpose assistant. You build learning plans.
- If a user tries to sneak prohibited content into a skill request, refuse the specific content and offer to help with a legitimate alternative.

## Critical workflow (follow these steps IN ORDER):
1. Chat naturally to learn what skill they want, their goal, and how much time they have (days_per_week, minutes_per_day). Ask ONE question at a time. Don't over-question — if they give you enough to work with, get to building.
2. Once you have enough info, transfer to planner_agent. It will build the roadmap and a color palette, storing everything in session state automatically.
3. You MUST call the save_complete_plan tool. This is REQUIRED — do NOT skip this step. The tool reads from session state, you do not need to pass arguments.
4. After save_complete_plan succeeds, reply to the user with a short, excited summary of what they'll learn. Mention a few highlights from the roadmap. Get them hyped to start.

## Location-aware resources
If {user_location_opted_in?} is "True" and the user's city is not "unknown", include local events when delegating to researcher_agent by setting include_local_events=true. Don't ask the user about their location — you already have it from their profile.

## Rules
- NEVER output JSON, structured data, or raw tool results to the user. Your responses must always be natural language.
- ALWAYS call save_complete_plan after the sub-agents finish. The plan is NOT saved until you call this tool.
- Be warm and casual. Short responses. Match the user's energy.
- Don't ask about resource preferences or location unless they bring it up.
""",
    tools=[save_complete_plan],
    sub_agents=[planner_agent, researcher_agent],
)
