enum NodeStatus { not_started, in_progress, completed, skipped }

enum ResourceType { youtube, article, book, exercise, event }

class Resource {
  final ResourceType type;
  final String title;
  final String url;

  const Resource({
    required this.type,
    required this.title,
    required this.url,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      type: ResourceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ResourceType.article,
      ),
      title: json['title'] as String,
      url: json['url'] as String,
    );
  }
}

class Branch {
  final String branchId;
  final String name;
  final String? divergedFromNodeId;
  final String? parentBranchId;
  final String firstNodeId;
  final String tipNodeId;
  final bool isArchived;

  const Branch({
    required this.branchId,
    required this.name,
    this.divergedFromNodeId,
    this.parentBranchId,
    required this.firstNodeId,
    required this.tipNodeId,
    this.isArchived = false,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      branchId: json['branch_id'] as String,
      name: json['name'] as String,
      divergedFromNodeId: json['diverged_from_node_id'] as String?,
      parentBranchId: json['parent_branch_id'] as String?,
      firstNodeId: json['first_node_id'] as String,
      tipNodeId: json['tip_node_id'] as String,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }
}

class PlanNode {
  final String nodeId;
  final String branchId;
  final int nodeNumber;
  final String title;
  final String description;
  final NodeStatus status;
  final List<Resource> resources;

  const PlanNode({
    required this.nodeId,
    required this.branchId,
    required this.nodeNumber,
    required this.title,
    required this.description,
    required this.status,
    required this.resources,
  });

  factory PlanNode.fromJson(Map<String, dynamic> json) {
    return PlanNode(
      nodeId: json['node_id'] as String,
      branchId: json['branch_id'] as String,
      nodeNumber: json['node_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: NodeStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => NodeStatus.not_started,
      ),
      resources: (json['resources'] as List<dynamic>? ?? [])
          .map((r) => Resource.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Plan {
  final String id;
  final String skillName;
  final String? description;
  final List<PlanNode> nodes;
  final List<Branch> branches;
  final String activeBranchId;

  const Plan({
    required this.id,
    required this.skillName,
    this.description,
    required this.nodes,
    required this.branches,
    required this.activeBranchId,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      skillName: json['skill_name'] as String,
      description: json['description'] as String?,
      nodes: (json['nodes'] as List<dynamic>)
          .map((n) => PlanNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      branches: (json['branches'] as List<dynamic>? ?? [])
          .map((b) => Branch.fromJson(b as Map<String, dynamic>))
          .toList(),
      activeBranchId: json['active_branch_id'] as String,
    );
  }
}
