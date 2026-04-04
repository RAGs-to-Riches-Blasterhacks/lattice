import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lattice/themes/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          scrimColor: Colors.transparent,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),
          // The drawer itself
          Drawer(
            width: 250,
            backgroundColor: AppColors.background,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            child: Column(
              children: [
                // Blue header with logo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
                  color: AppColors.background,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/CircleLogo.png',
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      // Hamburger icon closes drawer
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.menu,
                            color: AppColors.secondary,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu items on black background
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: Column(
                      children: [
                        _DrawerItem(
                          icon: Icons.home_outlined,
                          label: 'Home',
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: navigate to home
                          },
                        ),
                        const _DrawerDivider(),
                        _DrawerItem(
                          icon: Icons.person_outline,
                          label: 'Profile',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/profile');
                          },
                        ),
                        const _DrawerDivider(),
                        _DrawerItem(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings');
                          },
                        ),
                        const _DrawerDivider(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Divider(
        color: AppColors.cardBorder,
        height: 1,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.secondary, size: 28),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.secondary,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.secondary,
        size: 24,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
