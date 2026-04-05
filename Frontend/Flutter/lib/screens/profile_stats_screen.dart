import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lattice/models/user_stats.dart';
import 'package:lattice/services/api_service.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:provider/provider.dart';

class ProfileStatsScreen extends StatefulWidget {
  const ProfileStatsScreen({super.key});

  @override
  State<ProfileStatsScreen> createState() => _ProfileStatsScreenState();
}

class _ProfileStatsScreenState extends State<ProfileStatsScreen> {
  UserStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await context.read<ApiService>().getMyStats();

      // If all data is 0, use mock data for demonstration
      UserStats demonstrationStats = stats;
      if (stats.tasksCompletedByDay.every((d) => d.count == 0)) {
        demonstrationStats = UserStats(
          currentStreak: stats.currentStreak,
          longestStreak: stats.longestStreak,
          totalDaysActive: stats.totalDaysActive,
          totalTasksCompleted: 45,
          totalPlansCompleted: stats.totalPlansCompleted,
          tasksCompletedByDay: List.generate(30, (i) {
            final now = DateTime.now();
            final date = now.subtract(Duration(days: 29 - i));
            // Create varied mock data
            final count = (i % 7 == 0 ? 0 : (3 + (i % 5)));
            return DailyTaskCount(date: date, count: count);
          }),
        );
      }

      if (mounted) setState(() => _stats = demonstrationStats);
    } catch (_) {
      // Stats may not exist yet — that's fine
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Engagement Header
          _ProfileEngagementCard(
            currentStreak: _stats?.currentStreak ?? 0,
            longestStreak: _stats?.longestStreak ?? 0,
            tasksCompleted: _stats?.totalTasksCompleted ?? 0,
          ),
          const SizedBox(height: 24),

          // Activity Feed
          _ActivityFeed(days: _stats?.tasksCompletedByDay ?? []),
        ],
      ),
    );
  }
}

// Profile Engagement Header (like Instagram bio)
class _ProfileEngagementCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final int tasksCompleted;

  const _ProfileEngagementCard({
    required this.currentStreak,
    required this.longestStreak,
    required this.tasksCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(
          color: const Color(0xFF00C9C8).withValues(alpha: 0.4),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C9C8).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$currentStreak',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF28B95),
                    ),
                  ),
                  const Text(
                    'Streak',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFF28B95),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: AppColors.cardBorder,
              ),
              Column(
                children: [
                  Text(
                    '$tasksCompleted',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC3A6D4),
                    ),
                  ),
                  const Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC3A6D4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: AppColors.cardBorder,
              ),
              Column(
                children: [
                  Text(
                    '$longestStreak',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8FAFD4),
                    ),
                  ),
                  const Text(
                    'Best',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8FAFD4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Activity Feed (line chart)
class _ActivityFeed extends StatelessWidget {
  final List<DailyTaskCount> days;

  const _ActivityFeed({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final maxCount = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final yMax = maxCount > 0 ? (maxCount * 1.2).toDouble() : 10.0;

    // Create line chart spots
    final spots = List<FlSpot>.generate(
      days.length,
      (i) => FlSpot(i.toDouble(), days[i].count.toDouble()),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C9C8).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Feed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      maxCount > 0 ? (maxCount / 4).ceilToDouble() : 2.0,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF00C9C8).withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (days.length / 6).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < days.length) {
                          final date = days[index].date;
                          return Text(
                            '${date.month}/${date.day}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval:
                          maxCount > 0 ? (maxCount / 4).ceilToDouble() : 2.0,
                      getTitlesWidget: (value, meta) {
                        // Don't show label if it's very close to the maximum Y value boundary
                        if (value > yMax * 0.99) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF00C9C8).withValues(alpha: 0.2),
                      width: 1,
                    ),
                    left: BorderSide(
                      color: const Color(0xFF00C9C8).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                minX: 0,
                maxX: (days.length - 1).toDouble(),
                minY: 0,
                maxY: yMax,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: const Color(0xFF00C9C8),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: false,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFFF28B95),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00C9C8).withValues(alpha: 0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF1a1a1a).withValues(
                      alpha: 0.9,
                    ),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedBarSpot) {
                        final dayIndex = touchedBarSpot.x.toInt();
                        if (dayIndex >= 0 && dayIndex < days.length) {
                          final dayData = days[dayIndex];
                          final count = dayData.count;
                          final dateStr =
                              '${dayData.date.month}/${dayData.date.day}/${dayData.date.year}';
                          return LineTooltipItem(
                            '$dateStr\n$count tasks',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }
                        return LineTooltipItem(
                          '',
                          const TextStyle(),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
