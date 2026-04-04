class DailyTaskCount {
  final DateTime date;
  final int count;

  const DailyTaskCount({required this.date, required this.count});

  factory DailyTaskCount.fromJson(Map<String, dynamic> json) {
    return DailyTaskCount(
      date: DateTime.parse(json['date'] as String),
      count: json['count'] as int? ?? 0,
    );
  }
}

class UserStats {
  final int currentStreak;
  final int longestStreak;
  final int totalDaysActive;
  final int totalTasksCompleted;
  final int totalPlansCompleted;
  final List<DailyTaskCount> tasksCompletedByDay;

  const UserStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysActive,
    required this.totalTasksCompleted,
    required this.totalPlansCompleted,
    required this.tasksCompletedByDay,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      totalDaysActive: json['total_days_active'] as int? ?? 0,
      totalTasksCompleted: json['total_tasks_completed'] as int? ?? 0,
      totalPlansCompleted: json['total_plans_completed'] as int? ?? 0,
      tasksCompletedByDay: (json['tasks_completed_by_day'] as List<dynamic>?)
              ?.map((e) =>
                  DailyTaskCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
