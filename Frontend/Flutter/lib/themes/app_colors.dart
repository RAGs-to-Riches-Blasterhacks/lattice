import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF070405);
  static const Color secondary = Color(0xFFFBFBF2);
  static const Color accent = Color(0xFF33658A); // light blue
  static const Color activeTab = Color(0xFF89BBFE); // active toggle blue

  // Node status fill colors
  static const Color nodeNotStarted = Color(0xFF3A3A3A);
  static const Color nodeInProgress = accent;
  static const Color nodeCompleted = Color(0xFF4CAF50);
  static const Color nodeSkipped = Color(0xFF616161);

  // Connector line between nodes
  static const Color connectorLine = Color(0xFF2C2C2C);

  // Card / surface
  static const Color cardBackground = Color(0xFF111111);
  static const Color cardBorder = Color(0xFF2A2A2A);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);

  // Resource icon tints
  static const Color iconYoutube = Color(0xFFFF4444);
  static const Color iconBook = Color(0xFFFFB74D);
  static const Color iconArticle = Color(0xFF64B5F6);
  static const Color iconExercise = Color(0xFF81C784);
  static const Color iconEvent = Color(0xFFBA68C8);
}
