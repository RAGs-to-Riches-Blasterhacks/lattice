import 'package:flutter/material.dart';
import 'package:lattice/screens/profile_history_screen.dart';
import 'package:lattice/screens/profile_social_screen.dart';
import 'package:lattice/screens/profile_stats_screen.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/app_drawer.dart';
import 'package:lattice/widgets/plan_input_bar.dart';
import 'package:lattice/widgets/topnav.dart';

enum ProfileTab { stats, history, social }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileTab _activeTab = ProfileTab.stats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopNav(),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'DisplayName\'s Profile', // add user's display name here!
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Tab row — centered
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTab('STATS', ProfileTab.stats),
                      _buildDivider(),
                      _buildTab('HISTORY', ProfileTab.history),
                      _buildDivider(),
                      _buildTab('SOCIAL', ProfileTab.social),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tab content
                Expanded(
                  child: _buildTabContent(),
                ),
              ],
            ),
          ),
          const PlanInputBar(),
        ],
      ),
    );
  }

  Widget _buildTab(String label, ProfileTab tab) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.activeTab : AppColors.textSecondary,
            fontSize: isActive ? 16 : 14,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.normal,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 16,
      color: AppColors.textSecondary,
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case ProfileTab.stats:
        return const ProfileStatsScreen();
      case ProfileTab.history:
        return const ProfileHistoryScreen();
      case ProfileTab.social:
        return const ProfileSocialScreen();
    }
  }
}
