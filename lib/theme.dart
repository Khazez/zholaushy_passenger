import 'package:flutter/material.dart';

// ─── Палитра ────────────────────────────────────────────────────────────────

const kNavy    = Color(0xFF0D1F6E); // тёмно-синий — как текст логотипа
const kTeal    = Color(0xFF17A8C4); // бирюза — как стрела и машина в логотипе
const kBg      = Color(0xFFF4F7FF); // очень светло-голубой фон
const kCard    = Color(0xFFFFFFFF); // белые карточки
const kText    = Color(0xFF0D1F6E); // основной текст
const kSubtext = Color(0xFF6B7A99); // второстепенный текст

// Градиент — как в логотипе, от тёмно-синего к бирюзовому
const kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kNavy, kTeal],
);

const kGradientVertical = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [kNavy, Color(0xFF1565C0), kTeal],
  stops: [0.0, 0.5, 1.0],
);

// ─── Тема приложения ────────────────────────────────────────────────────────

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: kNavy,
      secondary: kTeal,
      surface: kCard,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: kText,
    ),
    scaffoldBackgroundColor: kBg,
    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: kNavy.withOpacity(0.08),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kTeal, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: kText, fontWeight: FontWeight.w800, fontSize: 28),
      headlineMedium: TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge: TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge: TextStyle(color: kText, fontSize: 15),
      bodyMedium: TextStyle(color: kSubtext, fontSize: 13),
    ),
  );
}
