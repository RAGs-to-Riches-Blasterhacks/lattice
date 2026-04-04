from datetime import datetime
from uuid import uuid4

from app.models.plan import Branch, Plan, PlanNode

# Fields that constitute a "core change" and trigger branching.
CORE_FIELDS = {"title", "description"}
CORE_OPTION_FIELDS = {"title", "description"}


def is_core_change(old_node: PlanNode, changes: dict) -> bool:
    """Determine if the proposed changes to a node alter its core learning objective."""
    for field in CORE_FIELDS:
        if field in changes and changes[field] != getattr(old_node, field):
            return True

    if "options" in changes and old_node.options:
        old_options = {o.option_id: o for o in old_node.options}
        for new_opt in changes["options"]:
            opt_id = new_opt.option_id if hasattr(new_opt, "option_id") else new_opt.get("option_id")
            if opt_id and opt_id in old_options:
                old = old_options[opt_id]
                for field in CORE_OPTION_FIELDS:
                    new_val = getattr(new_opt, field, None) if hasattr(new_opt, field) else new_opt.get(field)
                    if new_val is not None and new_val != getattr(old, field):
                        return True

    return False


def _find_node(plan: Plan, node_id: str) -> PlanNode | None:
    for node in plan.nodes:
        if node.node_id == node_id:
            return node
    return None


def _get_branch(plan: Plan, branch_id: str) -> Branch | None:
    for branch in plan.branches:
        if branch.branch_id == branch_id:
            return branch
    return None


def _nodes_on_branch(plan: Plan, branch_id: str) -> list[PlanNode]:
    return sorted(
        [n for n in plan.nodes if n.branch_id == branch_id],
        key=lambda n: n.node_number,
    )


def get_active_path(plan: Plan) -> list[PlanNode]:
    """Resolve the full ordered node sequence for the active branch, including shared ancestors."""
    path: list[PlanNode] = []
    branch = _get_branch(plan, plan.active_branch_id)
    if branch is None:
        return path

    # Collect ancestor prefix by walking up parent branches
    prefixes: list[list[PlanNode]] = []
    current_branch = branch
    while current_branch is not None:
        branch_nodes = _nodes_on_branch(plan, current_branch.branch_id)
        if current_branch.branch_id == branch.branch_id:
            # The active branch — include all its nodes
            prefixes.append(branch_nodes)
        else:
            # Parent branch — include nodes up to and including the divergence point
            diverge_id = None
            for child in plan.branches:
                if child.parent_branch_id == current_branch.branch_id:
                    # Find the child that led us here
                    diverge_id = child.diverged_from_node_id
                    break
            # Walk through this branch's nodes, stop after divergence node
            prefix = []
            for node in branch_nodes:
                prefix.append(node)
                if node.node_id == diverge_id:
                    break
            prefixes.append(prefix)

        if current_branch.parent_branch_id is None:
            break
        current_branch = _get_branch(plan, current_branch.parent_branch_id)

    # Reverse to get root-first order, then flatten
    prefixes.reverse()
    for segment in prefixes:
        path.extend(segment)

    return path


def create_branch(
    plan: Plan,
    node_id: str,
    changes: dict,
    branch_name: str | None = None,
) -> Plan:
    """Create a new branch from a core change on the given node.

    Returns the mutated plan (not yet persisted).
    """
    old_node = _find_node(plan, node_id)
    if old_node is None:
        raise ValueError(f"Node {node_id} not found in plan")

    old_branch_id = old_node.branch_id
    old_branch_nodes = _nodes_on_branch(plan, old_branch_id)

    new_branch_id = str(uuid4())
    now = datetime.utcnow()

    if branch_name is None:
        branch_count = len(plan.branches)
        branch_name = f"branch-{branch_count + 1}"

    # The divergence point is the node before the changed one
    prev_node_id = old_node.prev_node_id

    # Build the modified node
    new_node_id = str(uuid4())
    new_node = PlanNode(
        node_id=new_node_id,
        branch_id=new_branch_id,
        node_number=old_node.node_number,
        title=changes.get("title", old_node.title),
        description=changes.get("description", old_node.description),
        skill_level=changes.get("skill_level", old_node.skill_level),
        type_of_task=changes.get("type_of_task", old_node.type_of_task),
        options=changes.get("options", old_node.options),
        resources=changes.get("resources", old_node.resources),
        prev_node_id=prev_node_id,
        created_at=now,
    )

    new_nodes = [new_node]
    tip_node_id = new_node_id
    prev_id = new_node_id

    # Create placeholder nodes for all subsequent nodes on the old branch
    subsequent = [n for n in old_branch_nodes if n.node_number > old_node.node_number]
    for old_subsequent in subsequent:
        placeholder_id = str(uuid4())
        placeholder = PlanNode(
            node_id=placeholder_id,
            branch_id=new_branch_id,
            node_number=old_subsequent.node_number,
            title=old_subsequent.title,
            description=old_subsequent.description,
            skill_level=old_subsequent.skill_level,
            type_of_task=old_subsequent.type_of_task,
            prev_node_id=prev_id,
            needs_regeneration=True,
            created_at=now,
        )
        new_nodes.append(placeholder)
        tip_node_id = placeholder_id
        prev_id = placeholder_id

    # Wire next_node_ids
    for i, node in enumerate(new_nodes[:-1]):
        node.next_node_ids = [new_nodes[i + 1].node_id]

    # Create branch ref
    new_branch = Branch(
        branch_id=new_branch_id,
        name=branch_name,
        diverged_from_node_id=prev_node_id,
        parent_branch_id=old_branch_id,
        first_node_id=new_node_id,
        tip_node_id=tip_node_id,
        created_at=now,
    )

    plan.nodes.extend(new_nodes)
    plan.branches.append(new_branch)
    plan.active_branch_id = new_branch_id
    plan.updated_at = now
    plan.generation_version += 1

    return plan


def switch_branch(plan: Plan, branch_id: str) -> Plan:
    """Switch the active branch."""
    branch = _get_branch(plan, branch_id)
    if branch is None:
        raise ValueError(f"Branch {branch_id} not found")
    if branch.is_archived:
        raise ValueError(f"Branch {branch_id} is archived")
    plan.active_branch_id = branch_id
    plan.updated_at = datetime.utcnow()
    return plan


def apply_node_edit(
    plan: Plan, node_id: str, changes: dict
) -> tuple[Plan, bool]:
    """Apply an edit to a node. Returns (updated_plan, did_branch).

    If the change is core, creates a new branch.
    If non-core, edits the node in place.
    """
    old_node = _find_node(plan, node_id)
    if old_node is None:
        raise ValueError(f"Node {node_id} not found")

    if is_core_change(old_node, changes):
        return create_branch(plan, node_id, changes), True

    # Non-core: edit in place
    for field, value in changes.items():
        if field == "notes_to_add" and value:
            from app.models.plan import NodeNote
            old_node.notes.append(NodeNote(content=value))
        elif hasattr(old_node, field) and field not in CORE_FIELDS:
            setattr(old_node, field, value)

    plan.updated_at = datetime.utcnow()
    return plan, False
