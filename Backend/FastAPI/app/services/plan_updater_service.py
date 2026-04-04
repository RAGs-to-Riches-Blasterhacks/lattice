import logging
import os

from app.core.config import settings

os.environ.setdefault("OPENAI_API_KEY", settings.OPENAI_API_KEY)

from google.adk.runners import Runner
from google.genai.types import Content, Part

from app.agents.plan_updater.agent import plan_updater_agent
from app.models.plan import Plan
from app.models.user import User
from app.services.mongo_session_service import MongoSessionService

logger = logging.getLogger(__name__)

_session_service = MongoSessionService()

_runner = Runner(
    agent=plan_updater_agent,
    app_name="lattice-updater",
    session_service=_session_service,
)


class UpdaterResponse:
    """Holds the updater agent's text response."""

    def __init__(self, text: str):
        self.text = text


async def get_updater_response(
    plan_id: str,
    user: User,
    user_message: str,
    conv_id: str,
) -> UpdaterResponse:
    """Run the plan updater agent for a specific plan.

    Reuses a persistent session keyed by conv_id so the agent has
    multi-turn conversation history.
    """
    user_id = str(user.id)

    # Verify ownership before even creating a session
    plan = await Plan.get(plan_id)
    if plan is None or plan.user_id != user.id:
        return UpdaterResponse(text="Plan not found.")

    # Reuse session across turns so the agent sees conversation history
    session = await _session_service.get_session(
        app_name="lattice-updater",
        user_id=user_id,
        session_id=conv_id,
    )
    if session is None:
        session = await _session_service.create_session(
            app_name="lattice-updater",
            user_id=user_id,
            session_id=conv_id,
            state={
                "user_id": user_id,
                "plan_id": plan_id,
            },
        )

    content = Content(
        role="user",
        parts=[Part.from_text(text=user_message)],
    )

    final_text = ""

    async for event in _runner.run_async(
        user_id=user_id,
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
        logger.info(
            "UPDATER EVENT author=%s is_final=%s text_preview=%.120s",
            author, is_final, text,
        )

        if is_final and author == "plan_updater_agent":
            final_text = text

    if not final_text.strip():
        final_text = "I've made some changes to your plan. Want me to walk you through them?"

    return UpdaterResponse(text=final_text)
