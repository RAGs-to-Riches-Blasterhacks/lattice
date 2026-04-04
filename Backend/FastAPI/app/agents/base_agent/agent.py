import litellm
litellm.suppress_debug_info = True

from google.adk.agents import LlmAgent
from google.adk.models.lite_llm import LiteLlm
from google.adk.tools import agent_tool

MODEL = LiteLlm(model="openai/gpt-4o-mini")


# ---------------------------------------------------------------------------
# Planner Agent
# Creates a step-by-step roadmap of tasks to reach the learning goal
# ---------------------------------------------------------------------------

planner_agent = LlmAgent(
    model=MODEL,
    name="planner_agent",
    description="Creates a structured learning roadmap with individual tasks for a given skill and end goal.",
    instruction="""You are a learning path expert. When given a skill and end goal, produce a roadmap.

Output between 5 and 8 tasks that progressively build toward the end goal.
For each task include:
- task_number
- title
- description (1-2 sentences on what to do)
- estimated_time (e.g. "2 hours", "3 days")

Respond only with a JSON object like:
{
  "skill": "<skill>",
  "end_goal": "<end_goal>",
  "tasks": [
    { "task_number": 1, "title": "...", "description": "...", "estimated_time": "..." },
    ...
  ]
}""",
)


# ---------------------------------------------------------------------------
# Researcher Agent
# For a given task, surfaces tutorials, articles, and a plain-English guide
# ---------------------------------------------------------------------------

def find_youtube_tutorials(topic: str) -> dict:
    """Find YouTube tutorials for a learning topic.

    Args:
        topic: The topic or task to search tutorials for.

    Returns:
        A dict with the topic and placeholder tutorial results.
        Replace this stub with a real YouTube Data API v3 call.
    """
    return {
        "topic": topic,
        "tutorials": [
            {"title": f"[stub] Intro to {topic}", "url": "https://youtube.com", "channel": "Example Channel"},
            {"title": f"[stub] {topic} for beginners", "url": "https://youtube.com", "channel": "Example Channel"},
        ],
        "note": "Stub — wire up YouTube Data API v3 to get real results.",
    }


def find_articles(topic: str) -> dict:
    """Find articles and documentation for a learning topic.

    Args:
        topic: The topic or task to search articles for.

    Returns:
        A dict with the topic and placeholder article results.
        Replace this stub with a real search API call (e.g. Google Custom Search).
    """
    return {
        "topic": topic,
        "articles": [
            {"title": f"[stub] Getting started with {topic}", "url": "https://example.com/article1"},
            {"title": f"[stub] {topic} deep dive", "url": "https://example.com/article2"},
        ],
        "note": "Stub — wire up Google Custom Search or similar to get real results.",
    }


researcher_agent = LlmAgent(
    model=MODEL,
    name="researcher_agent",
    description="Researches a specific learning task and returns YouTube tutorials, articles, and a plain-English guide.",
    instruction="""You are a research assistant helping someone learn a specific task.

When given a task title and description:
1. Call find_youtube_tutorials with the task topic to get video resources.
2. Call find_articles with the task topic to get written resources.
3. Write a plain-English "how to tackle this" section (3-5 sentences) explaining what to focus on and in what order.

Respond with a JSON object like:
{
  "task": "<task title>",
  "tutorials": [ ... ],
  "articles": [ ... ],
  "guide": "<plain-English description>"
}""",
    tools=[find_youtube_tutorials, find_articles],
)


# ---------------------------------------------------------------------------
# UI Color Agent
# Analyzes the skill theme and returns a matching color palette
# ---------------------------------------------------------------------------

ui_agent = LlmAgent(
    model=MODEL,
    name="ui_agent",
    description="Analyzes a skill or learning goal and generates a thematically matching UI color palette.",
    instruction="""You are a UI/UX designer specializing in color theory.

Given a skill or end goal:
1. Identify the mood, domain, and associations of the topic (e.g. tech = blues, nature = greens).
2. Choose 5 colors: primary, secondary, accent, background, text.
3. For each color provide: role, hex, name, and a one-sentence rationale.

Respond only with a JSON object like:
{
  "theme": "<brief theme description>",
  "palette": [
    { "role": "primary", "hex": "#...", "name": "...", "rationale": "..." },
    { "role": "secondary", "hex": "#...", "name": "...", "rationale": "..." },
    { "role": "accent", "hex": "#...", "name": "...", "rationale": "..." },
    { "role": "background", "hex": "#...", "name": "...", "rationale": "..." },
    { "role": "text", "hex": "#...", "name": "...", "rationale": "..." }
  ]
}""",
)


# ---------------------------------------------------------------------------
# Root Orchestrator
# Coordinates the three agents above via AgentTool
# ---------------------------------------------------------------------------

root_agent = LlmAgent(
    model=MODEL,
    name="root_agent",
    description="Orchestrates a skill-learning system: plans a roadmap, researches each task, and generates a UI palette.",
    instruction="""You are a skill-learning orchestrator. When a user tells you a skill they want to learn and their end goal:

1. Call planner_agent with the skill and end goal to get a task roadmap.
2. For each task in the roadmap, call researcher_agent to get tutorials, articles, and a guide.
3. Call ui_agent with the skill and end goal to get a matching UI color palette.
4. Return a single comprehensive response combining the roadmap, per-task research, and the color palette.

Always complete all three steps before responding.""",
    tools=[
        agent_tool.AgentTool(agent=planner_agent),
        agent_tool.AgentTool(agent=researcher_agent),
        agent_tool.AgentTool(agent=ui_agent),
    ],
)
