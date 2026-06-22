import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors (Light Theme)
  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color primaryBlue = Color(0xFF0284C7); // Sky 600 (Vibrant Blue)
  static const Color accentSky = Color(0xFF38BDF8); // Sky 300

  // Alias definitions to automatically migrate all screens to the new light theme
  static const Color darkBg = lightBg;
  static const Color darkCard = lightCard;
  static const Color darkBorder = lightBorder;
  static const Color primaryTeal = primaryBlue;
  static const Color accentNeon = accentSky;

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600

  // Status Colors (Harmonized Pastel tones for Light Theme)
  static const Color statusPending = Color(0xFFD97706); // Amber 600
  static const Color statusPendingBg = Color(0xFFFEF3C7); // Amber 100
  
  static const Color statusFollowUp = Color(0xFF4F46E5); // Indigo 600
  static const Color statusFollowUpBg = Color(0xFFE0E7FF); // Indigo 100
  
  static const Color statusCompleted = Color(0xFF059669); // Emerald 600
  static const Color statusCompletedBg = Color(0xFFD1FAE5); // Emerald 100
  
  static const Color statusDefault = Color(0xFF475569); // Slate 600
  static const Color statusDefaultBg = Color(0xFFF1F5F9); // Slate 100

  static Color getStatusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'pending') {
      return statusPending;
    } else if (s == 'follow up' || s == 'followup' || s == 'follow') {
      return statusFollowUp;
    } else {
      return statusCompleted;
    }
  }

  static Color getStatusBgColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'pending') {
      return statusPendingBg;
    } else if (s == 'follow up' || s == 'followup' || s == 'follow') {
      return statusFollowUpBg;
    } else {
      return statusCompletedBg;
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentSky,
        surface: lightCard,
        background: lightBg,
        error: Colors.red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: primaryBlue.withOpacity(0.3),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
