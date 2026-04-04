"""ADK SessionService backed by MongoDB via Motor.

Stores sessions in a single ``adk_sessions`` collection with events as
embedded documents.  Uses the same Motor client that the rest of the app
shares, so no extra connection pool is needed.
"""

import json
import time
import uuid
from typing import Any, Optional

from google.adk.events import Event
from google.adk.sessions.base_session_service import (
    BaseSessionService,
    GetSessionConfig,
    ListSessionsResponse,
)
from google.adk.sessions.session import Session


class MongoSessionService(BaseSessionService):

    def __init__(self, collection_name: str = "adk_sessions"):
        self._collection_name = collection_name

    @property
    def _collection(self):
        from app.core.database import get_db
        return get_db()[self._collection_name]

    # ------------------------------------------------------------------
    # Serialisation helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _serialize_event(event: Event) -> dict:
        """Event → JSON-safe dict suitable for MongoDB storage."""
        return json.loads(event.model_dump_json())

    @staticmethod
    def _deserialize_event(data: dict) -> Event:
        return Event.model_validate(data)

    @staticmethod
    def _doc_id(app_name: str, user_id: str, session_id: str) -> str:
        return f"{app_name}:{user_id}:{session_id}"

    # ------------------------------------------------------------------
    # BaseSessionService implementation
    # ------------------------------------------------------------------

    async def create_session(
        self,
        *,
        app_name: str,
        user_id: str,
        state: Optional[dict[str, Any]] = None,
        session_id: Optional[str] = None,
    ) -> Session:
        session_id = session_id or str(uuid.uuid4())
        now = time.time()

        doc = {
            "_id": self._doc_id(app_name, user_id, session_id),
            "session_id": session_id,
            "app_name": app_name,
            "user_id": user_id,
            "state": state or {},
            "events": [],
            "last_update_time": now,
        }
        await self._collection.insert_one(doc)

        return Session(
            id=session_id,
            app_name=app_name,
            user_id=user_id,
            state=state or {},
            events=[],
            last_update_time=now,
        )

    async def get_session(
        self,
        *,
        app_name: str,
        user_id: str,
        session_id: str,
        config: Optional[GetSessionConfig] = None,
    ) -> Optional[Session]:
        doc = await self._collection.find_one(
            {"_id": self._doc_id(app_name, user_id, session_id)}
        )
        if doc is None:
            return None

        events = [self._deserialize_event(e) for e in doc.get("events", [])]

        if config:
            if config.num_recent_events is not None:
                events = events[-config.num_recent_events:]
            if config.after_timestamp is not None:
                events = [
                    e
                    for e in events
                    if (e.timestamp or 0) >= config.after_timestamp
                ]

        return Session(
            id=doc["session_id"],
            app_name=doc["app_name"],
            user_id=doc["user_id"],
            state=doc.get("state", {}),
            events=events,
            last_update_time=doc.get("last_update_time", 0),
        )

    async def list_sessions(
        self, *, app_name: str, user_id: Optional[str] = None
    ) -> ListSessionsResponse:
        query: dict[str, Any] = {"app_name": app_name}
        if user_id:
            query["user_id"] = user_id

        sessions: list[Session] = []
        async for doc in self._collection.find(query, {"events": 0}):
            sessions.append(
                Session(
                    id=doc["session_id"],
                    app_name=doc["app_name"],
                    user_id=doc["user_id"],
                    state=doc.get("state", {}),
                    events=[],
                    last_update_time=doc.get("last_update_time", 0),
                )
            )
        return ListSessionsResponse(sessions=sessions)

    async def delete_session(
        self, *, app_name: str, user_id: str, session_id: str
    ) -> None:
        await self._collection.delete_one(
            {"_id": self._doc_id(app_name, user_id, session_id)}
        )

    async def append_event(self, session: Session, event: Event) -> Event:
        # Base class handles in-memory state delta application
        event = await super().append_event(session, event)

        # Persist the new event and updated state to MongoDB
        now = time.time()
        await self._collection.update_one(
            {"_id": self._doc_id(session.app_name, session.user_id, session.id)},
            {
                "$push": {"events": self._serialize_event(event)},
                "$set": {
                    "state": session.state,
                    "last_update_time": now,
                },
            },
        )
        return event
