class Streak {
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final int totalDaysActive;
  final DateTime? lastActivityDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Streak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysActive,
    this.lastActivityDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      userId: json['user_id'] as String,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      totalDaysActive: json['total_days_active'] as int? ?? 0,
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
