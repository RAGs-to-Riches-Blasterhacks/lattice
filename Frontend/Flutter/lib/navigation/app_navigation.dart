import 'package:flutter/material.dart';
import 'package:lattice/screens/home_screen.dart';
import 'package:lattice/screens/landing_screen.dart';
import 'package:lattice/screens/login_screen.dart';
import 'package:lattice/screens/profile_screen.dart';
import 'package:lattice/screens/roadmap.dart';
import 'package:lattice/screens/settings_screen.dart';

class AppNavigation {
  AppNavigation._();

  static const String landingRoute = '/landing';
  static const String homeRoute = '/home';
  static const String loginRoute = '/login';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';
  static const String roadmapRoute = '/roadmap';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      landingRoute => const LandingScreen(),
      loginRoute => const LoginScreen(),
      profileRoute => const ProfileScreen(),
      settingsRoute => const SettingsScreen(),
      roadmapRoute => RoadmapScreen(planId: settings.arguments as String?),
      _ => const HomeScreen(),
    };

    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<void> goToHome(BuildContext context) {
    return _replaceStack(context, homeRoute);
  }

  static Future<void> goToLogin(BuildContext context) {
    return _replaceCurrent(context, loginRoute);
  }

  static Future<void> goToProfile(BuildContext context) {
    return _replaceCurrent(context, profileRoute);
  }

  static Future<void> goToSettings(BuildContext context) {
    return _replaceCurrent(context, settingsRoute);
  }

  static Future<void> goToRoadmap(BuildContext context, {String? planId}) {
    return Navigator.of(context).pushNamed(roadmapRoute, arguments: planId);
  }

  static Future<void> _replaceCurrent(BuildContext context, String routeName) {
    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isDrawerOpen = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;

    if (currentRoute == routeName) {
      if (isDrawerOpen) {
        navigator.pop();
      }
      return Future.value();
    }

    if (isDrawerOpen) {
      navigator.pop();
    }

    return Future<void>.delayed(const Duration(milliseconds: 120), () async {
      await navigator.pushReplacementNamed(routeName);
    });
  }

  static Future<void> _replaceStack(BuildContext context, String routeName) {
    final navigator = Navigator.of(context);
    final isDrawerOpen = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;

    if (isDrawerOpen) {
      navigator.pop();
    }

    return Future<void>.delayed(const Duration(milliseconds: 120), () async {
      await navigator.pushNamedAndRemoveUntil(routeName, (route) => false);
    });
  }
}
