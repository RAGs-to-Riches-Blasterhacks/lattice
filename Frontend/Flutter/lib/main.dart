import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lattice/navigation/app_navigation.dart';
import 'package:lattice/providers/auth_provider.dart';
import 'package:lattice/providers/plans_provider.dart';
import 'package:lattice/screens/home_screen.dart';
import 'package:lattice/screens/login_screen.dart';
import 'package:lattice/services/api_service.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const LatticeApp());
}

class LatticeApp extends StatelessWidget {
  const LatticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(apiService),
        ),
        ChangeNotifierProvider<PlansProvider>(
          create: (_) => PlansProvider(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Lattice',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.dark(
            surface: AppColors.background,
            primary: AppColors.accent,
            secondary: AppColors.secondary,
          ),
          textTheme: GoogleFonts.dmSansTextTheme(
            ThemeData.dark().textTheme,
          ),
        ),
        home: const _AuthGate(),
        onGenerateRoute: AppNavigation.onGenerateRoute,
      ),
    );
  }

}

/// Shows [LoginScreen] while auth is loading or when logged out.
/// Shows [HomeScreen] when the user is authenticated.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
          ),
        ),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return const HomeScreen();
  }
}
