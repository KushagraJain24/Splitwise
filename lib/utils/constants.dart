import 'dart:ui';
import 'package:flutter/material.dart';

class AppConstants {
  // Multi Currency Config
  static String currencySymbol = "₹";

  // Harmonic Color Palettes
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color accentTeal = Color(0xFF06B6D4);
  static const Color accentIndigo = Color(0xFF6366F1);

  // Credit (You are owed) - Slate Green/Emerald
  static const Color creditGreen = Color(0xFF10B981);
  static const Color creditGreenLight = Color(0xFFD1FAE5);

  // Debit (You owe) - Rose/Coral/Amber
  static const Color debitOrange = Color(0xFFF43F5E);
  static const Color debitOrangeLight = Color(0xFFFFE4E6);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  // Glassmorphic Decoration helper
  static BoxDecoration glassDecoration({
    required Color color,
    double opacity = 0.08,
    double borderRadius = 16.0,
    double borderOpacity = 0.1,
  }) {
    return BoxDecoration(
      color: color.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(borderOpacity),
        width: 1.0,
      ),
    );
  }

  // Visual Gradient backgrounds
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E1E38),
      Color(0xFF0B0F19),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
