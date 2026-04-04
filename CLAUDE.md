# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Lattice is a skill-building app where an LLM agent creates personalized learning plans. The defining feature is **git-like plan branching**: when a user changes a node's core learning objective, the plan graph forks and subsequent nodes are regenerated.

## Repository Layout

- `Backend/FastAPI/` — Python FastAPI backend (MongoDB via Beanie ODM, Firebase Auth)
- `Frontend/Flutter/` — Flutter mobile app (provider for state, go_router for navigation)

## Build & Run

### Backend

```bash
cd Backend/FastAPI
pip install -r requirements.txt
uvicorn main:app --reload
```

Requires a `.env` file (see `.env.example`): MongoDB Atlas connection string, Firebase credentials path, and Firebase API key. The `.env` is gitignored.

Health check: `GET /health`

### Frontend

```bash
cd Frontend/Flutter
flutter pub get
flutter run
```

## Architecture

### Backend Structure

All backend code lives under `Backend/FastAPI/app/`:

- `core/` — Config (`pydantic-settings`), database init (Motor + Beanie), Firebase init, rate limiting middleware, security dependency (`get_current_user`)
- `models/` — Beanie Document classes: `User`, `Plan`, `PlanVersion`, `Conversation`, `Streak`. All registered via `ALL_DOCUMENT_MODELS` in `models/__init__.py`.
- `schemas/` — Pydantic request/response schemas (separate from DB models)
- `services/` — Business logic. `plan_service.py` contains the core branching engine; `auth_service.py` handles Firebase auth flows.
- `api/` — Route definitions. `routes.py` is the top-level router (mounted at `/api`). Sub-routers (e.g., `auth.py`) are included there.

### The Plan Graph (Core Domain)

A `Plan` contains a flat list of `PlanNode` objects and lightweight `Branch` refs. The active branch is tracked by `Plan.active_branch_id` (analogous to git HEAD).

**Branching trigger**: Editing a node's `title`, `description`, or option `title`/`description` (the "core fields" defined in `plan_service.py:CORE_FIELDS`). Non-core field edits (status, notes, selected option, resources) are applied in-place.

**Branch creation flow** (`plan_service.create_branch`):
1. New branch ref created pointing to the divergence point
2. Modified node created on the new branch
3. Placeholder nodes created for subsequent positions with `needs_regeneration=True`
4. `active_branch_id` set to new branch, `generation_version` incremented
5. Original branch nodes are preserved (no deletion)

**Path resolution** (`plan_service.get_active_path`): Walks up `parent_branch_id` chain collecting ancestor prefixes, then flattens root-first.

### Auth Flow

Firebase Auth for identity. `get_current_user` (in `core/security.py`) is the FastAPI dependency that verifies Firebase ID tokens and resolves the `User` document. Auth routes at `/api/auth/` handle register, login, and OAuth token exchange. Rate limited at 10 req/min for auth, 60 req/min globally.

### Database

MongoDB Atlas (no local MongoDB). Beanie ODM with async Motor driver. Collections: `users`, `plans`, `plan_versions` (60-day TTL), `conversations` (60-day TTL after completion), `streaks` (one per user, global across plans).

### Frontend

Flutter with Material 3, provider for state management, go_router for routing. API calls go through `services/api_service.dart`.
