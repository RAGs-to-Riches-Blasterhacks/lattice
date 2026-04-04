import 'package:flutter/material.dart';
import 'package:lattice/providers/auth_provider.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/app_drawer.dart';
import 'package:lattice/widgets/chat_overlay.dart';
import 'package:lattice/widgets/topnav.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopNav(),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Scrollable settings content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                // Account section
                _buildSectionHeader('Account'),
                const SizedBox(height: 8),
                _buildSettingsGroup(const [
                  _SettingsItem(Icons.person_outline, 'Account Management'),
                  _SettingsItem(Icons.notifications_outlined, 'Notifications'),
                  _SettingsItem(Icons.accessibility_new_outlined, 'Accessibility Features'),
                  _SettingsItem(Icons.translate, 'Language'),
                ]),
                const SizedBox(height: 24),

                // About section
                _buildSectionHeader('About'),
                const SizedBox(height: 8),
                _buildSettingsGroup(const [
                  _SettingsItem(Icons.computer_outlined, 'Website Application'),
                  _SettingsItem(Icons.info_outline, 'Privacy Policies'),
                  _SettingsItem(Icons.error_outline, 'Terms & Conditions'),
                ]),
                const SizedBox(height: 24),

                // Actions section
                _buildSectionHeader('Actions'),
                const SizedBox(height: 8),
                _buildSettingsGroup(
                  const [
                    _SettingsItem(Icons.help_outline, 'Support/FAQ'),
                    _SettingsItem(Icons.logout, 'Log Out'),
                    _SettingsItem(Icons.delete_outline, 'Delete Account'),
                  ],
                  onTap: (label) {
                    if (label == 'Log Out') {
                      context.read<AuthProvider>().logout();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                ),
              ],
            ),
          ),

          const ChatOverlay(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.secondary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSettingsGroup(
    List<_SettingsItem> items, {
    void Function(String label)? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: items
            .map(
              (item) => GestureDetector(
                onTap: onTap != null ? () => onTap(item.label) : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(item.icon, color: AppColors.secondary, size: 24),
                      const SizedBox(width: 16),
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  const _SettingsItem(this.icon, this.label);
}
