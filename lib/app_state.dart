import 'package:flutter/material.dart';

class AppState {
  static final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final langNotifier  = ValueNotifier<String>('ru');

  static ThemeMode parseTheme(String s) {
    switch (s) {
      case 'dark':  return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      default:      return ThemeMode.system;
    }
  }

  static String themeKey(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:  return 'dark';
      case ThemeMode.light: return 'light';
      default:              return 'system';
    }
  }
}
