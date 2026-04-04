import json
import logging
import os

from app.core.config import settings

# Ensure API keys are in the environment for litellm / google-adk
os.environ.setdefault("OPENAI_API_KEY", settings.OPENAI_API_KEY)
os.environ.setdefault("GOOGLE_API_KEY", settings.GOOGLE_API_KEY)
os.environ.setdefault("GOOGLE_CSE_ID", settings.GOOGLE_CSE_ID)
os.environ.setdefault("EVENTBRITE_TOKEN", settings.EVENTBRITE_TOKEN)

from google.adk.runners import Runner
from google.genai.types import Content, Part

from app.agents.base_agent.agent import persist_plan, root_agent
from app.models.user import User
from app.services.mongo_session_service import MongoSessionService

logger = logging.getLogger(__name__)

_session_service = MongoSessionService()

_runner = Runner(
    agent=root_agent,
    app_name="lattice",
    session_service=_session_service,
)


def _looks_like_json(text: str) -> bool:
    """Return True if text appears to be raw JSON rather than natural language."""
    stripped = text.strip()
    return stripped.startswith(("{", "[")) and stripped.endswith(("}", "]"))


def _build_user_state(user: User, conv_id: str, plan_id: str | None) -> dict:
    """Build ADK session state dict from user profile and conversation context."""
    return {
        "user_id": str(user.id),
        "conv_id": conv_id,
        "plan_id": plan_id or "",
        "user_name": user.display_name,
        "user_timezone": user.timezone,
        "user_city": user.location.city or "unknown",
        "user_state": user.location.state or "unknown",
        "user_country": user.location.country or "unknown",
        "user_location_opted_in": str(user.location.opted_in),
    }


async def _get_or_create_session(
    conv_id: str, user: User, plan_id: str | None
):
    """Return an existing ADK session for this conversation, or create one."""
    user_id = str(user.id)

    session = await _session_service.get_session(
        app_name="lattice",
        user_id=user_id,
        session_id=conv_id,
    )
    if session is not None:
        return session

    return await _session_service.create_session(
        app_name="lattice",
        user_id=user_id,
        session_id=conv_id,
        state=_build_user_state(user, conv_id, plan_id),
    )


def _build_synthetic_summary(plan_data: dict) -> str:
    """Build a friendly summary from raw plan data when the model didn't produce one."""
    skill = plan_data.get("skill", "your new skill")
    nodes = plan_data.get("nodes", [])
    node_count = len(nodes)

    highlights = [n.get("title", "") for n in nodes[:3] if n.get("title")]
    highlight_text = ""
    if highlights:
        highlight_text = " You'll start with " + ", then ".join(highlights) + "."

    return (
        f"Your {skill} learning plan is ready! "
        f"I've mapped out {node_count} steps to get you there.{highlight_text} "
        f"Check out your plan to see the full roadmap!"
    )


class AgentResponse:
    """Holds the agent's text response and any newly-saved plan_id."""

    def __init__(self, text: str, plan_id: str | None = None):
        self.text = text
        self.plan_id = plan_id


async def get_agent_response(
    conv_id: str,
    user: User,
    user_message: str,
    plan_id: str | None = None,
) -> AgentResponse:
    """Run the ADK agent and return the response.

    Only captures text from root_agent. Sub-agent structured output is
    kept internal to session state and never returned as conversation text.
    """
    session = await _get_or_create_session(conv_id, user, plan_id)

    # Snapshot plan_id before the run so we can detect NEW saves
    plan_id_before = session.state.get("plan_id", "") if session.state else ""

    content = Content(
        role="user",
        parts=[Part.from_text(text=user_message)],
    )

    root_text = ""

    async for event in _runner.run_async(
        user_id=str(user.id),
        session_id=session.id,
        new_message=content,
    ):
        if not (event.content and event.content.parts):
            continue

        text = ""
        for part in event.content.parts:
            if part.text:
                text = part.text

        if not text:
            continue

        author = getattr(event, "author", None)
        is_final = event.is_final_response()
        logger.info("EVENT author=%s is_final=%s text_preview=%.120s", author, is_final, text)

        if is_final and author == "root_agent":
            root_text = text

    # Refresh session to check post-run state
    refreshed = await _session_service.get_session(
        app_name="lattice",
        user_id=str(user.id),
        session_id=session.id,
    )
    state = refreshed.state if refreshed else {}
    plan_id_after = state.get("plan_id", "")

    # --- Safety net: persist plan if model skipped save_complete_plan ---
    new_plan_id = None
    plan_result_raw = state.get("plan_result")
    if plan_result_raw and plan_id_after == plan_id_before:
        # Sub-agents produced data but save_complete_plan was never called
        logger.info("Safety net: save_complete_plan was not called by the model — persisting plan programmatically.")
        try:
            # Clear plan_id so persist_plan creates a NEW plan instead of
            # overwriting whatever plan was previously linked to this session.
            safety_state = {**state, "plan_id": ""}
            result = await persist_plan(safety_state)
            if result.get("plan_id"):
                new_plan_id = result["plan_id"]
                # Persist the updated plan_id and clear plan_result so the
                # safety net doesn't re-trigger on subsequent turns.
                doc_id = _session_service._doc_id("lattice", str(user.id), session.id)
                await _session_service._collection.update_one(
                    {"_id": doc_id},
                    {"$set": {
                        "state.plan_id": new_plan_id,
                        "state.plan_result": None,
                    }},
                )
        except Exception:
            logger.exception("Safety net: failed to persist plan")
    elif plan_id_after and plan_id_after != plan_id_before:
        new_plan_id = plan_id_after

    # --- Build final response text ---
    final = root_text

    # Guard against JSON leaking as root_agent text
    if final and _looks_like_json(final):
        logger.warning("Root agent returned JSON instead of natural language — replacing with synthetic summary.")
        final = ""

    # If no usable text but plan was saved, generate a synthetic summary
    if not final and (new_plan_id or plan_result_raw):
        try:
            plan_data = json.loads(plan_result_raw) if isinstance(plan_result_raw, str) else plan_result_raw
            if isinstance(plan_data, dict):
                final = _build_synthetic_summary(plan_data)
        except (json.JSONDecodeError, TypeError):
            pass

    if not final:
        final = "I'm sorry, I wasn't able to generate a response. Could you try again?"

    return AgentResponse(text=final, plan_id=new_plan_id)
