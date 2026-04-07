class Message {
  final String role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const Message({
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class Conversation {
  final String id;
  final String userId;
  final String? planId;
  final List<Message> messages;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const Conversation({
    required this.id,
    required this.userId,
    this.planId,
    required this.messages,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String?,
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}
