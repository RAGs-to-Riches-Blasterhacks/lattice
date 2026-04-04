enum NodeStatus { not_started, in_progress, completed, skipped }

enum PlanStatus { active, paused, completed, abandoned }

enum ResourceType { youtube, article, book, exercise, event }

class Resource {
  final ResourceType type;
  final String title;
  final String url;
  final int? durationMinutes;
  final bool isOptional;

  const Resource({
    required this.type,
    required this.title,
    required this.url,
    this.durationMinutes,
    this.isOptional = false,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      type: ResourceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ResourceType.article,
      ),
      title: json['title'] as String,
      url: json['url'] as String,
      durationMinutes: json['duration_minutes'] as int?,
      isOptional: json['is_optional'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'url': url,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        'is_optional': isOptional,
      };
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

/// A timestamped note attached to a plan node.
class NodeNote {
  final String content;
  final DateTime createdAt;

  const NodeNote({required this.content, required this.createdAt});

  factory NodeNote.fromJson(Map<String, dynamic> json) {
    return NodeNote(
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// A single activity log entry for a plan node.
class ActivityEntry {
  final DateTime date;
  final String? note;

  const ActivityEntry({required this.date, this.note});

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
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
  final List<NodeNote> notes;
  final List<ActivityEntry> activityLog;
  final String? skillLevel;
  final String? typeOfTask;
  final bool needsRegeneration;

  const PlanNode({
    required this.nodeId,
    required this.branchId,
    required this.nodeNumber,
    required this.title,
    required this.description,
    required this.status,
    required this.resources,
    this.notes = const [],
    this.activityLog = const [],
    this.skillLevel,
    this.typeOfTask,
    this.needsRegeneration = false,
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
      notes: (json['notes'] as List<dynamic>? ?? [])
          .map((n) => NodeNote.fromJson(n as Map<String, dynamic>))
          .toList(),
      activityLog: (json['activity_log'] as List<dynamic>? ?? [])
          .map((a) => ActivityEntry.fromJson(a as Map<String, dynamic>))
          .toList(),
      skillLevel: json['skill_level'] as String?,
      typeOfTask: json['type_of_task'] as String?,
      needsRegeneration: json['needs_regeneration'] as bool? ?? false,
    );
  }
}

class PaletteColor {
  final String role;
  final String hex;
  final String name;

  const PaletteColor({
    required this.role,
    required this.hex,
    required this.name,
  });

  factory PaletteColor.fromJson(Map<String, dynamic> json) {
    return PaletteColor(
      role: json['role'] as String,
      hex: json['hex'] as String,
      name: json['name'] as String,
    );
  }
}

class Palette {
  final String theme;
  final List<PaletteColor> colors;

  const Palette({required this.theme, required this.colors});

  factory Palette.fromJson(Map<String, dynamic> json) {
    return Palette(
      theme: json['theme'] as String? ?? '',
      colors: (json['colors'] as List<dynamic>? ?? [])
          .map((c) => PaletteColor.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Plan {
  final String id;
  final String? userId;
  final String skillName;
  final String? description;
  final List<PlanNode> nodes;
  final List<Branch> branches;
  final String activeBranchId;
  final Palette? palette;
  final PlanStatus status;
  final String? currentNodeId;
  final int? daysPerWeek;
  final int? minutesPerDay;
  final int generationVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Plan({
    required this.id,
    this.userId,
    required this.skillName,
    this.description,
    required this.nodes,
    required this.branches,
    required this.activeBranchId,
    this.palette,
    this.status = PlanStatus.active,
    this.currentNodeId,
    this.daysPerWeek,
    this.minutesPerDay,
    this.generationVersion = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      skillName: json['skill_name'] as String,
      description: json['description'] as String?,
      nodes: (json['nodes'] as List<dynamic>)
          .map((n) => PlanNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      branches: (json['branches'] as List<dynamic>? ?? [])
          .map((b) => Branch.fromJson(b as Map<String, dynamic>))
          .toList(),
      activeBranchId: json['active_branch_id'] as String,
      palette: json['palette'] != null
          ? Palette.fromJson(json['palette'] as Map<String, dynamic>)
          : null,
      status: PlanStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PlanStatus.active,
      ),
      currentNodeId: json['current_node_id'] as String?,
      daysPerWeek: json['days_per_week'] as int?,
      minutesPerDay: json['minutes_per_day'] as int?,
      generationVersion: json['generation_version'] as int? ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Get the primary color from palette, or a default.
  int get primaryColorValue {
    if (palette != null && palette!.colors.isNotEmpty) {
      final primary = palette!.colors.where((c) => c.role == 'primary');
      final hex =
          primary.isNotEmpty ? primary.first.hex : palette!.colors.first.hex;
      return int.tryParse(hex.replaceFirst('#', 'FF'), radix: 16) ?? 0xFF33658A;
    }
    return 0xFF33658A;
  }
}

/// Lightweight plan summary for list views (from GET /plans).
class PlanSummary {
  final String id;
  final String skillName;
  final String? description;
  final PlanStatus status;
  final String activeBranchId;
  final int branchCount;
  final int nodeCount;
  final int completedNodeCount;
  final String? currentNodeId;
  final String? currentNodeTitle;
  final String? currentNodeDescription;
  final List<Resource> currentNodeResources;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlanSummary({
    required this.id,
    required this.skillName,
    this.description,
    required this.status,
    required this.activeBranchId,
    required this.branchCount,
    required this.nodeCount,
    required this.completedNodeCount,
    this.currentNodeId,
    this.currentNodeTitle,
    this.currentNodeDescription,
    this.currentNodeResources = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanSummary.fromJson(Map<String, dynamic> json) {
    return PlanSummary(
      id: json['id'] as String,
      skillName: json['skill_name'] as String,
      description: json['description'] as String?,
      status: PlanStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PlanStatus.active,
      ),
      activeBranchId: json['active_branch_id'] as String,
      branchCount: json['branch_count'] as int? ?? 0,
      nodeCount: json['node_count'] as int? ?? 0,
      completedNodeCount: json['completed_node_count'] as int? ?? 0,
      currentNodeId: json['current_node_id'] as String?,
      currentNodeTitle: json['current_node_title'] as String?,
      currentNodeDescription: json['current_node_description'] as String?,
      currentNodeResources:
          (json['current_node_resources'] as List<dynamic>? ?? [])
              .map((r) => Resource.fromJson(r as Map<String, dynamic>))
              .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
