import os
import re

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
# Evaluator Output Schema
# ---------------------------------------------------------------------------


class EvaluationCriterionOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str
    score: float = Field(ge=0.0, le=1.0)
    comment: str = ""


class EvaluationOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    overall_score: float = Field(ge=0.0, le=1.0)
    criteria: list[EvaluationCriterionOutput] = Field(default_factory=list)
    strengths: list[str] = Field(default_factory=list)
    weaknesses: list[str] = Field(default_factory=list)
    fix_instructions: list[str] = Field(default_factory=list)

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
    instruction="""
You are a learning path designer.

Input:
- skill
- end_goal
- days_per_week
- minutes_per_day

First call:
- estimate_difficulty
- get_prerequisites

Use:
- estimate_difficulty → decide roadmap length and pacing
- get_prerequisites → include or skip foundational steps

---

Safety:
Only allow legitimate skills.
If unsafe, return:
{"error": "This skill is outside what Lattice can help with."}

---

Approach:
- Get the user doing real work immediately
- Prioritize practice/projects over passive learning
- Avoid fluff
- Slightly challenge the user
- Design like a real practitioner would

At least 70% of nodes must involve active creation, practice, or problem-solving.

Each node must produce something observable (file, project, recording, solved problem, etc).
Avoid vague outcomes like “understand” or “learn”.

---

Roadmap rules:
- skill: 2-5 word title
- 5-30 nodes based on difficulty
- Each node must fit within minutes_per_day (single session only)
- Start simple → include stretch steps

Each node:
- title
- description (casual, experienced tone)
- task_type (practice | project | exploration)
- skill_level (beginner | intermediate | advanced)
- success_levels (real-world phrasing)
- options (0-3, meaningfully different, optional)
- resources (2-5 items)

Resources:
- type: youtube | article | book | exercise | event
- title: specific and real
- url: or ""
- duration_minutes: int or 0
- is_optional: bool
- Mix types across nodes

---

Color palette:
- primary (must reflect skill's real-world vibe)
- secondary (different hue)
- accent (different hue)
- background
- text (near-black)

Avoid generic palettes. Ensure readability with black text.

---

Output (JSON):
{
  "skill": "",
  "nodes": [...],
  "palette": {
    "primary": {"name": "", "hex": "", "rationale": ""},
    "secondary": {"name": "", "hex": "", "rationale": ""},
    "accent": {"name": "", "hex": "", "rationale": ""},
    "background": {"name": "", "hex": "", "rationale": ""},
    "text": {"name": "", "hex": "", "rationale": ""}
  }
}
""",
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
# Plan Evaluator
# ---------------------------------------------------------------------------

EVAL_MAX_RETRIES = 3
EVAL_THRESHOLD = 0.85
EVAL_MODEL = "openai/gpt-5.4"  # Different model than planner (mini) to avoid self-grading bias
_ACTIVE_TASK_TYPES = {"practice", "project", "exploration"}
_SKILL_LEVEL_ORDER = {"beginner": 0, "intermediate": 1, "advanced": 2}
_VAGUE_PATTERNS = re.compile(
    r"\b(understand|learn about|familiarize|get comfortable|explore the basics of|"
    r"read about|review|overview of|introduction to)\b",
    re.IGNORECASE,
)
_MIN_NODES = 5
_MAX_NODES = 30


# --- Structural pre-checks (fail-fast before LLM eval) --------------------


def _structural_precheck(plan_data: dict) -> list[str]:
    """Check for structurally broken plans that no amount of prompting will fix.

    Returns a list of fatal issues. Empty list means plan is structurally sound.
    """
    issues = []
    nodes = plan_data.get("nodes", [])

    if not nodes:
        issues.append("Plan has zero nodes.")
        return issues

    if len(nodes) < _MIN_NODES:
        issues.append(f"Plan has only {len(nodes)} nodes (minimum {_MIN_NODES}).")
    if len(nodes) > _MAX_NODES:
        issues.append(f"Plan has {len(nodes)} nodes (maximum {_MAX_NODES}).")

    # Check required fields on every node
    required = {"title", "skill_level", "type_of_task"}
    for n in nodes:
        missing = required - set(n.keys())
        if missing:
            issues.append(
                f"Node {n.get('node_number', '?')} missing fields: {', '.join(missing)}."
            )

    # Check for duplicate titles
    titles = [n.get("title", "") for n in nodes]
    dupes = {t for t in titles if titles.count(t) > 1 and t}
    if dupes:
        issues.append(f"Duplicate node titles: {', '.join(dupes)}.")

    if not plan_data.get("skill"):
        issues.append("Plan missing skill name.")
    if not plan_data.get("end_goal"):
        issues.append("Plan missing end_goal.")

    return issues


# --- Deterministic scoring ------------------------------------------------


def _compute_deterministic_scores(plan_data: dict) -> dict:
    """Compute scores that don't need an LLM — just counting and checking.

    Returns a dict of {criterion_name: {score, comment, details}}.
    """
    nodes = plan_data.get("nodes", [])
    total = len(nodes) or 1

    # 1. practice_ratio: % of nodes with active task types
    active_count = sum(
        1 for n in nodes if n.get("type_of_task", "").lower() in _ACTIVE_TASK_TYPES
    )
    practice_ratio = active_count / total
    practice_score = min(1.0, practice_ratio / 0.7)  # 70% = 1.0, linear below
    passive_nodes = [
        n.get("node_number", "?") for n in nodes
        if n.get("type_of_task", "").lower() not in _ACTIVE_TASK_TYPES
    ]

    # 2. progression: check skill_level ordering isn't jumbled
    levels = [
        _SKILL_LEVEL_ORDER.get(n.get("skill_level", "").lower(), -1)
        for n in nodes
    ]
    valid_levels = [l for l in levels if l >= 0]
    if len(valid_levels) >= 2:
        # Count ordering violations (a node harder than a later node)
        violations = sum(
            1 for i in range(len(valid_levels) - 1)
            if valid_levels[i] > valid_levels[i + 1]
        )
        progression_score = max(0.0, 1.0 - (violations / (len(valid_levels) - 1)))
    else:
        progression_score = 0.5  # Can't evaluate with < 2 levels

    # 3. no_fluff: check for vague descriptions
    vague_nodes = []
    for n in nodes:
        desc = n.get("description", "")
        title = n.get("title", "")
        if _VAGUE_PATTERNS.search(title) or (
            desc and len(desc) < 20
        ):
            vague_nodes.append(n.get("node_number", "?"))
    fluff_ratio = len(vague_nodes) / total
    no_fluff_score = max(0.0, 1.0 - fluff_ratio * 2)  # 50%+ vague = 0.0

    # 4. time_integrity: flag overloaded (5+ resources) or empty (no description) nodes
    overloaded = []
    empty = []
    for n in nodes:
        res_count = len(n.get("resources", []))
        if res_count >= 5:
            overloaded.append(n.get("node_number", "?"))
        if not n.get("description", "").strip():
            empty.append(n.get("node_number", "?"))
    time_problems = len(overloaded) + len(empty)
    time_score = max(0.0, 1.0 - (time_problems / total))

    # 5. resource_quality: check variety of resource types across the plan
    all_resource_types = set()
    nodes_with_resources = 0
    for n in nodes:
        resources = n.get("resources", [])
        if resources:
            nodes_with_resources += 1
            for r in resources:
                all_resource_types.add(r.get("type", ""))
    type_variety = min(1.0, len(all_resource_types) / 3)  # 3+ types = full marks
    resource_coverage = nodes_with_resources / total
    resource_score = (type_variety + resource_coverage) / 2

    return {
        "practice_ratio": {
            "score": round(practice_score, 2),
            "comment": f"{active_count}/{total} active nodes ({practice_ratio:.0%})",
            "details": {"passive_nodes": passive_nodes},
        },
        "progression": {
            "score": round(progression_score, 2),
            "comment": f"{violations} ordering violation(s)" if len(valid_levels) >= 2 else "Too few levels to evaluate",
            "details": {},
        },
        "no_fluff": {
            "score": round(no_fluff_score, 2),
            "comment": f"{len(vague_nodes)} vague node(s)" + (f": {vague_nodes}" if vague_nodes else ""),
            "details": {"vague_nodes": vague_nodes},
        },
        "time_integrity": {
            "score": round(time_score, 2),
            "comment": (
                f"{len(overloaded)} overloaded, {len(empty)} empty"
                if time_problems else "All nodes well-sized"
            ),
            "details": {"overloaded": overloaded, "empty": empty},
        },
        "resource_quality": {
            "score": round(resource_score, 2),
            "comment": f"{len(all_resource_types)} resource type(s), {nodes_with_resources}/{total} nodes have resources",
            "details": {"types_found": list(all_resource_types)},
        },
    }


# --- LLM-based subjective evaluation (only what we can't count) -----------

LLM_EVAL_PROMPT = """\
Score this learning plan's SUBJECTIVE quality. Deterministic checks (practice ratio, \
progression order, resource variety) are handled separately — focus only on:

- tangible_outcomes (0.0-1.0): Does every node produce something observable? \
A file, project, recording, solved problem — not just "understand" or "be familiar with."
- engagement (0.0-1.0): Would a motivated learner stay interested? Variety in approaches? \
Avoids long stretches of the same task type?

Also return:
- strengths: what works well (list of strings)
- weaknesses: what needs fixing (list of strings)
- fix_instructions: specific actionable fixes for the planner (list of strings). \
Empty if both scores >= {threshold}.

Return JSON:
{{"tangible_outcomes": <float>, "engagement": <float>, "strengths": [...], "weaknesses": [...], "fix_instructions": [...]}}

Plan: {skill} | Goal: {end_goal} | {days_per_week}d/wk, {minutes_per_day}min/day

{nodes_text}
"""

REGEN_ADDON = """\
Improve the previous plan using these fixes:
{fix_instructions}

Do not repeat mistakes. Keep what works, fix what doesn't.

Previous plan:
{previous_plan_summary}
"""


def _format_nodes_for_eval(nodes: list[dict]) -> str:
    """Format plan nodes into readable text for the evaluator."""
    lines = []
    for n in nodes:
        options_str = ""
        if n.get("options"):
            opts = ", ".join(o.get("title", "") for o in n["options"])
            options_str = f"\n    Options: {opts}"
        resources_str = ""
        if n.get("resources"):
            res = ", ".join(
                f'{r.get("type", "?")}:{r.get("title", "?")}'
                for r in n["resources"]
            )
            resources_str = f"\n    Resources: {res}"

        lines.append(
            f"  Node {n.get('node_number', '?')}: {n.get('title', '?')} "
            f"[{n.get('skill_level', '?')}, {n.get('type_of_task', '?')}]\n"
            f"    {n.get('description', '')}"
            f"{options_str}{resources_str}"
        )
    return "\n".join(lines)


# --- Combined evaluation (deterministic + LLM) ----------------------------


async def _evaluate_plan(plan_data: dict) -> dict:
    """Hybrid evaluation: deterministic scores + LLM for subjective criteria.

    Returns a combined evaluation dict with all criteria, overall_score,
    strengths, weaknesses, and fix_instructions.
    """
    import json as _json

    # Deterministic scores
    det_scores = _compute_deterministic_scores(plan_data)

    # LLM subjective scores (different model than planner)
    nodes_text = _format_nodes_for_eval(plan_data.get("nodes", []))
    prompt = LLM_EVAL_PROMPT.format(
        skill=plan_data.get("skill", ""),
        end_goal=plan_data.get("end_goal", ""),
        days_per_week=plan_data.get("days_per_week", 3),
        minutes_per_day=plan_data.get("minutes_per_day", 20),
        threshold=EVAL_THRESHOLD,
        nodes_text=nodes_text,
    )

    response = await litellm.acompletion(
        model=EVAL_MODEL,
        messages=[
            {"role": "system", "content": "You are a strict learning plan quality evaluator. Be honest — do not inflate scores."},
            {"role": "user", "content": prompt},
        ],
        response_format={"type": "json_object"},
        temperature=0.2,
    )

    llm_raw = _json.loads(response.choices[0].message.content)

    # Merge all criteria
    criteria = []
    for name, data in det_scores.items():
        criteria.append({"name": name, "score": data["score"], "comment": data["comment"]})
    for name in ("tangible_outcomes", "engagement"):
        criteria.append({
            "name": name,
            "score": round(max(0.0, min(1.0, llm_raw.get(name, 0.5))), 2),
            "comment": f"LLM-assessed",
        })

    # Weighted average: practice_ratio 2x, tangible_outcomes 2x, rest 1x
    weights = {
        "practice_ratio": 2, "tangible_outcomes": 2,
        "progression": 1, "time_integrity": 1,
        "resource_quality": 1, "no_fluff": 1, "engagement": 1,
    }
    score_map = {c["name"]: c["score"] for c in criteria}
    weighted_sum = sum(score_map.get(k, 0.5) * w for k, w in weights.items())
    total_weight = sum(weights.values())
    overall_score = round(weighted_sum / total_weight, 2)

    # Build fix_instructions: combine LLM suggestions with deterministic findings
    fix_instructions = list(llm_raw.get("fix_instructions", []))

    # Add deterministic-derived fixes
    det_details = det_scores
    if det_details["practice_ratio"]["score"] < 0.85:
        passive = det_details["practice_ratio"]["details"].get("passive_nodes", [])
        if passive:
            fix_instructions.append(
                f"Convert passive nodes {passive} to hands-on practice/project tasks."
            )
    if det_details["no_fluff"]["score"] < 0.85:
        vague = det_details["no_fluff"]["details"].get("vague_nodes", [])
        if vague:
            fix_instructions.append(
                f"Rewrite vague nodes {vague} with specific, actionable descriptions and titles."
            )
    if det_details["time_integrity"]["score"] < 0.85:
        overloaded = det_details["time_integrity"]["details"].get("overloaded", [])
        empty = det_details["time_integrity"]["details"].get("empty", [])
        if overloaded:
            fix_instructions.append(f"Nodes {overloaded} have too many resources — trim to 2-4.")
        if empty:
            fix_instructions.append(f"Nodes {empty} have no description — add meaningful content.")
    if det_details["resource_quality"]["score"] < 0.85:
        types_found = det_details["resource_quality"]["details"].get("types_found", [])
        fix_instructions.append(
            f"Only {len(types_found)} resource type(s) used ({types_found}). Mix in youtube, article, exercise, book."
        )

    # Clear fix_instructions if we passed
    if overall_score >= EVAL_THRESHOLD:
        fix_instructions = []

    return {
        "overall_score": overall_score,
        "criteria": criteria,
        "strengths": llm_raw.get("strengths", []),
        "weaknesses": llm_raw.get("weaknesses", []),
        "fix_instructions": fix_instructions,
    }


# --- Fix verification (did the regenerated plan actually address fixes?) ---


def _verify_fixes_applied(
    old_weaknesses: list[str],
    old_fix_instructions: list[str],  # noqa: ARG001 — reserved for future fine-grained matching
    new_evaluation: dict,
) -> dict:
    """Check whether previous weaknesses were addressed in the new plan.

    Compares old weaknesses/fixes against new evaluation's weaknesses.
    Returns a summary of what was fixed and what persists.
    """
    new_weaknesses = set(w.lower() for w in new_evaluation.get("weaknesses", []))
    old_weakness_set = set(w.lower() for w in old_weaknesses)

    fixed = old_weakness_set - new_weaknesses
    persisting = old_weakness_set & new_weaknesses
    new_issues = new_weaknesses - old_weakness_set

    return {
        "fixed": list(fixed),
        "persisting": list(persisting),
        "new_issues": list(new_issues),
        "fix_rate": len(fixed) / max(1, len(old_weakness_set)),
    }


# --- Retry loop -----------------------------------------------------------


async def evaluate_and_refine_plan(tool_context: ToolContext) -> dict:
    """Evaluate the generated plan and retry if quality is below threshold.

    Reads plan_result from session state. Runs structural pre-checks, then
    hybrid evaluation (deterministic + LLM). If score < 0.85, regenerates
    with targeted fixes up to 3 attempts. Tracks the highest-scoring plan
    across all attempts.

    No arguments needed — reads from and writes to session state.

    Returns:
        A dict with the final evaluation score, attempt count, and status.
    """
    import json as _json

    plan_raw = tool_context.state.get("plan_result", "")
    try:
        plan_data = _json.loads(plan_raw) if isinstance(plan_raw, str) else plan_raw
    except (_json.JSONDecodeError, TypeError):
        return {"error": "No valid plan_result in session state."}

    if not plan_data or not isinstance(plan_data, dict):
        return {"error": "No plan data found. Transfer to planner_agent first."}

    # Structural pre-check — fail fast on broken plans
    structural_issues = _structural_precheck(plan_data)
    if structural_issues:
        return {
            "error": "Plan is structurally broken and needs full regeneration.",
            "issues": structural_issues,
        }

    original_input = {
        "skill": plan_data.get("skill", ""),
        "end_goal": plan_data.get("end_goal", ""),
        "days_per_week": plan_data.get("days_per_week", 3),
        "minutes_per_day": plan_data.get("minutes_per_day", 20),
    }

    best_plan = plan_data
    best_score = 0.0
    current_plan = plan_data
    attempts = []
    prev_weaknesses: list[str] = []
    prev_fix_instructions: list[str] = []

    for attempt in range(EVAL_MAX_RETRIES):
        evaluation = await _evaluate_plan(current_plan)
        score = evaluation.get("overall_score", 0.0)
        fix_instructions = evaluation.get("fix_instructions", [])

        # Verify fixes from previous round were applied
        fix_verification = None
        if attempt > 0 and prev_weaknesses:
            fix_verification = _verify_fixes_applied(
                prev_weaknesses, prev_fix_instructions, evaluation,
            )

        attempt_record = {
            "attempt": attempt + 1,
            "score": score,
            "criteria": evaluation.get("criteria", []),
            "strengths": evaluation.get("strengths", []),
            "weaknesses": evaluation.get("weaknesses", []),
            "fix_count": len(fix_instructions),
        }
        if fix_verification:
            attempt_record["fix_verification"] = fix_verification
        attempts.append(attempt_record)

        # Track the highest-scoring plan
        if score > best_score:
            best_score = score
            best_plan = current_plan

        if score >= EVAL_THRESHOLD:
            break

        if attempt >= EVAL_MAX_RETRIES - 1:
            break

        # Prepare for regeneration
        prev_weaknesses = evaluation.get("weaknesses", [])
        prev_fix_instructions = fix_instructions

        # If fixes from last round weren't applied, escalate the instructions
        if fix_verification and fix_verification["fix_rate"] < 0.5:
            fix_instructions = [
                f"CRITICAL (unfixed from last attempt): {fi}"
                for fi in fix_instructions
            ]

        previous_summary = _format_nodes_for_eval(current_plan.get("nodes", []))
        fix_text = "\n".join(f"- {f}" for f in fix_instructions)

        regen_addon = REGEN_ADDON.format(
            fix_instructions=fix_text,
            previous_plan_summary=previous_summary,
        )

        regen_messages = [
            {"role": "system", "content": planner_agent.instruction},
            {"role": "user", "content": (
                f"Create a learning plan for:\n"
                f"Skill: {original_input['skill']}\n"
                f"End goal: {original_input['end_goal']}\n"
                f"Schedule: {original_input['days_per_week']} days/week, "
                f"{original_input['minutes_per_day']} min/day\n\n"
                f"{regen_addon}"
            )},
        ]

        response = await litellm.acompletion(
            model="openai/gpt-5.4-mini",
            messages=regen_messages,
            response_format={"type": "json_object"},
            temperature=0.7,
        )

        raw = response.choices[0].message.content
        try:
            candidate = _json.loads(raw)
        except (_json.JSONDecodeError, TypeError):
            continue

        # Structural check on regenerated plan too
        regen_issues = _structural_precheck(candidate)
        if regen_issues:
            continue

        current_plan = candidate

    # Write the highest-scoring plan back to state
    tool_context.state["plan_result"] = best_plan
    tool_context.state["_eval_score"] = best_score
    tool_context.state["_eval_attempts"] = len(attempts)

    return {
        "status": "passed" if best_score >= EVAL_THRESHOLD else "best_effort",
        "final_score": best_score,
        "threshold": EVAL_THRESHOLD,
        "attempts": attempts,
        "message": (
            f"Plan scored {best_score:.2f} after {len(attempts)} attempt(s). "
            + ("Meets quality threshold." if best_score >= EVAL_THRESHOLD
               else "Below threshold — saving best effort.")
        ),
    }


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
3. After the planner finishes, call evaluate_and_refine_plan. No arguments needed.
4. Call save_complete_plan. REQUIRED — do NOT skip.
5. Reply with a short, excited summary of what they'll learn. Don't mention scores or evaluation internals.

## Location-aware resources
If {user_location_opted_in?} is "True" and the user's city is not "unknown", you have their location. Use it to find local events whenever relevant — both during plan creation and when the user just wants to explore what's happening nearby. Don't ask the user about their location — you already have it from their profile.

## Rules
- NEVER output JSON, structured data, or raw tool results to the user. Your responses must always be natural language.
- ALWAYS call save_complete_plan after the sub-agents finish building a plan. The plan is NOT saved until you call this tool.
- Be warm and casual. Short responses. Match the user's energy.
""",
    tools=[evaluate_and_refine_plan, save_complete_plan],
    sub_agents=[planner_agent, researcher_agent],
)
