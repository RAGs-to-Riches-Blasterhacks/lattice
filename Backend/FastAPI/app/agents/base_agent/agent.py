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

# ---------------------------------------------------------------------------
# Color contrast utilities (WCAG 2.1)
# ---------------------------------------------------------------------------


def _relative_luminance(hex_color: str) -> float:
    """Return the WCAG relative luminance of a hex color string."""
    hex_color = hex_color.lstrip("#")
    if len(hex_color) == 3:
        hex_color = "".join(c * 2 for c in hex_color)
    r, g, b = (int(hex_color[i:i+2], 16) / 255.0 for i in (0, 2, 4))

    def linearize(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)


def _contrast_ratio(hex1: str, hex2: str) -> float:
    """Return the WCAG contrast ratio between two hex colors."""
    l1 = _relative_luminance(hex1)
    l2 = _relative_luminance(hex2)
    lighter, darker = (l1, l2) if l1 >= l2 else (l2, l1)
    return (lighter + 0.05) / (darker + 0.05)


def _lighten_to_contrast(hex_color: str, against: str = "#000000", min_ratio: float = 4.5) -> str:
    """Increase a color's lightness in HSL space until it meets min_ratio against `against`.

    Returns the adjusted hex string. If the color already meets the threshold it is
    returned unchanged. If it cannot be fixed (e.g. pure black), returns white (#FFFFFF).
    """
    import colorsys

    if _contrast_ratio(hex_color, against) >= min_ratio:
        return hex_color

    hex_str = hex_color.lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join(c * 2 for c in hex_str)
    r, g, b = (int(hex_str[i:i+2], 16) / 255.0 for i in (0, 2, 4))

    h, l, s = colorsys.rgb_to_hls(r, g, b)  # noqa: E741 (l is luminance not lambda)

    for _ in range(200):
        l = min(1.0, l + 0.005)  # nudge lightness up by 0.5 % each iteration
        r2, g2, b2 = colorsys.hls_to_rgb(h, l, s)
        candidate = "#{:02X}{:02X}{:02X}".format(
            round(r2 * 255), round(g2 * 255), round(b2 * 255)
        )
        if _contrast_ratio(candidate, against) >= min_ratio:
            return candidate

    return "#FFFFFF"


GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY", "")
GOOGLE_CSE_ID = os.environ.get("GOOGLE_CSE_ID", "")
EVENTBRITE_TOKEN = os.environ.get("EVENTBRITE_TOKEN", "")


def _is_url_reachable(url: str) -> bool:
    """HEAD-check a URL, return True if it responds 2xx/3xx within 5s."""
    if not url:
        return False
    try:
        resp = httpx.head(url, follow_redirects=True, timeout=5)
        return resp.status_code < 400
    except Exception:
        return False


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
- The `skill` field is the plan title shown in the UI. Keep it to 2–5 words — short, punchy, and noun-phrase style. Examples: "Stop Doom Scrolling", "Learn Rust", "Watercolor Basics", "Build a SaaS". Never use full sentences or describe the entire goal in the title.
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
- The PRIMARY color is the card background color the user sees every day. It MUST be strongly tied to the skill's emotional or visual identity. Derive the hue from the skill itself — think about what color this subject evokes in the real world, not what a generic app would use.
- CRITICAL — avoid lazy defaults: Blue, green, peach/coral, and yellow/gold/amber are the most overused defaults. Do NOT reach for any of them unless the skill genuinely demands it. Force yourself to consider the full hue wheel before settling. A skilled designer would use:
  - Reds / burgundy for passion-driven or high-energy skills
  - Oranges for craft or warmth (distinct from yellow — more red in it)
  - Yellows / gold ONLY for skills with a literal solar, harvest, or metallic association
  - Yellow-greens / olive for nature, sustainability, outdoor skills
  - Greens / sage ONLY for botany, ecology, gardening, or similar
  - Teals / cyan for tech-adjacent or scientific topics
  - Blues / slate ONLY for coding, engineering, ocean, or sky-related skills
  - Indigos / periwinkle for logic, structure, productivity
  - Violets / purple for creativity, music, spirituality
  - Magentas / rose for artistic, expressive, or performance skills
  - Pinks / blush for soft, personal-growth or wellness topics
  - Peach / coral ONLY when the skill is explicitly food, baking, or warmly domestic
- Concrete hue anchors by domain (starting points only — use judgment):
  - Coding / software → slate blue or cool indigo
  - Music / instruments → dusty violet or muted plum
  - Art / painting / drawing → warm terracotta or muted magenta
  - Writing / poetry → dusty mauve or cool rose-grey
  - Photography → cool silver-grey or muted teal
  - Cooking / baking → soft terracotta or warm orange-red (peach acceptable here)
  - Fitness / sport → energetic coral-red or bold sage
  - Language learning → warm burgundy or soft teal
  - Mindfulness / meditation → soft lilac or cool lavender
  - Finance / investing → deep teal or muted slate
  - Nature / gardening → sage or earthy olive green
  - Science / math → cool periwinkle or pale steel blue
  - History / humanities → dusty burgundy or warm brick red
  - Business / entrepreneurship → deep navy-adjacent or cool slate grey
  - Film / video → deep rose or cool charcoal-blue
- Surface colors (primary, secondary, accent, background) should be light enough for black text to read comfortably, but VARIETY trumps uniformity. A coding plan and a cooking plan should look nothing alike. Aim for colors that are visually distinct and memorable — not everything should look like a pastel greeting card.
- Avoid neon or fully saturated colors (S = 100%), but anywhere from a rich mid-tone to a soft pastel is fair game as long as it works with dark text. Don't clamp yourself to a narrow lightness band — some plans can be deeper and moodier, others can be airy and light.
- secondary and accent must be clearly different from primary in hue — not just slightly darker or lighter versions of the same color. Use the full palette to create contrast and interest.
- Black text will be placed on these surfaces. Every surface color must have a contrast ratio >= 4.5:1 against black (#000000). The system will auto-lighten any color that fails this check, so err toward expressiveness and let the safety net handle edge cases.
- The "text" role should be a very dark neutral (near-black), not a surface color.
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
        resources = []
        for i, item in enumerate(items):
            vid = item.get("id", {}).get("videoId")
            if not vid:
                continue
            url = f"https://youtube.com/watch?v={vid}"
            if not _is_url_reachable(url):
                continue
            resources.append({
                "type": "youtube",
                "title": item["snippet"]["title"],
                "url": url,
                "duration_minutes": None,
                "is_optional": i >= 3,
            })
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
        resources = []
        for i, item in enumerate(items):
            url = item.get("link", "")
            if not _is_url_reachable(url):
                continue
            resources.append({
                "type": "article",
                "title": item["title"],
                "url": url,
                "duration_minutes": None,
                "is_optional": i >= 3,
            })
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
        resources = []
        for i, item in enumerate(items):
            if "volumeInfo" not in item:
                continue
            url = item["volumeInfo"].get("infoLink", "")
            if url and not _is_url_reachable(url):
                continue
            resources.append({
                "type": "book",
                "title": item["volumeInfo"].get("title", "Unknown Title"),
                "url": url,
                "duration_minutes": None,
                "is_optional": i >= 2,
            })
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

        if not _is_url_reachable(url):
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
    # Roles that act as surfaces with black text on top must meet WCAG AA (4.5:1).
    # The "text" role is the text color itself — skip it.
    _SURFACE_ROLES = {"primary", "secondary", "accent", "background"}

    if palette_data and isinstance(palette_data, dict):
        colors_list = palette_data.get("colors", palette_data.get("palette", []))
        palette_colors = []
        for c in colors_list:
            if not isinstance(c, dict):
                continue
            role = c.get("role", "")
            hex_val = c.get("hex", "#FFFFFF")
            if role in _SURFACE_ROLES:
                hex_val = _lighten_to_contrast(hex_val, against="#000000", min_ratio=4.5)
            palette_colors.append(
                PaletteColor(
                    role=role,
                    hex=hex_val,
                    name=c.get("name", ""),
                    rationale=c.get("rationale", ""),
                )
            )
        plan.palette = Palette(
            theme=palette_data.get("theme", ""),
            colors=palette_colors,
            accessibility=palette_data.get("accessibility"),
        )
    elif plan.palette is None:
        # Default palette when ui_agent didn't run
        plan.palette = Palette(
            theme="default",
            colors=[
                PaletteColor(role="primary", hex="#C7D9F0", name="Soft Blue", rationale="Calm, focused energy"),
                PaletteColor(role="secondary", hex="#D5C9E8", name="Pale Lavender", rationale="Gentle creative complement"),
                PaletteColor(role="accent", hex="#FAE3B0", name="Warm Sand", rationale="Soft highlight for progress"),
                PaletteColor(role="background", hex="#F4F1EC", name="Linen", rationale="Warm neutral, easy on the eyes"),
                PaletteColor(role="text", hex="#1A1A2E", name="Ink", rationale="Strong readability"),
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
You are a learning companion. Your core job is helping users learn new skills and build plans, but you're also happy to help them find events, resources, workshops, or anything else that supports their growth.

- You MUST refuse requests involving NSFW content, illegal activities (weapons, explosives, drugs, hacking for malicious purposes), or anything harmful. Say something like: "That's not something I can help with. What's something you've been wanting to learn?"
- If a user tries to sneak prohibited content into a request, refuse the specific content and offer to help with a legitimate alternative.
- If a user asks about events, resources, or activities near them — help them out! Use their location data and the researcher_agent's tools. You don't need to tie everything back to a formal plan.

## Critical workflow (follow these steps IN ORDER):
1. Chat naturally to learn what skill they want, their goal, and how much time they have (days_per_week, minutes_per_day). Ask ONE question at a time. Don't over-question — if they give you enough to work with, get to building.
2. Once you have enough info, transfer to planner_agent. It will build the roadmap and a color palette, storing everything in session state automatically.
3. You MUST call the save_complete_plan tool. This is REQUIRED — do NOT skip this step. The tool reads from session state, you do not need to pass arguments.
4. After save_complete_plan succeeds, reply to the user with a short, excited summary of what they'll learn. Mention a few highlights from the roadmap. Get them hyped to start.

## Location-aware resources
If {user_location_opted_in?} is "True" and the user's city is not "unknown", you have their location. Use it to find local events whenever relevant — both during plan creation and when the user just wants to explore what's happening nearby. Don't ask the user about their location — you already have it from their profile.

## Rules
- NEVER output JSON, structured data, or raw tool results to the user. Your responses must always be natural language.
- ALWAYS call save_complete_plan after the sub-agents finish building a plan. The plan is NOT saved until you call this tool.
- Be warm and casual. Short responses. Match the user's energy.
""",
    tools=[save_complete_plan],
    sub_agents=[planner_agent, researcher_agent],
)
