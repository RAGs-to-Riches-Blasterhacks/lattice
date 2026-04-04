import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lattice/navigation/app_navigation.dart';
import 'package:lattice/themes/app_colors.dart';

void main() {
  runApp(const LatticeApp());
}

class LatticeApp extends StatelessWidget {
  const LatticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      initialRoute: AppNavigation.homeRoute,
      onGenerateRoute: AppNavigation.onGenerateRoute,
    );
  }
}
