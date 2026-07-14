import 'package:flutter/material.dart';

/// 沉稳金融风：深蓝主色 + 暖琥珀强调，避免紫/奶油 AI 套模板。
class AppTheme {
  static const Color ink = Color(0xFF0F1C2E);
  static const Color slate = Color(0xFF1E3350);
  static const Color paper = Color(0xFFF3F6F9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFC45C26);
  static const Color sell = Color(0xFFB45309);
  static const Color buy = Color(0xFFB91C1C);
  static const Color muted = Color(0xFF64748B);
  static const Color softWarn = Color(0xFFFEF3C7);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: slate,
      brightness: Brightness.light,
      primary: slate,
      secondary: accent,
      surface: paper,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: paper,
      fontFamily: 'Segoe UI',
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ink,
            );
          }
          return const TextStyle(fontSize: 12, color: muted);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}
