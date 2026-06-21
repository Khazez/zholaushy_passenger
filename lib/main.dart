import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ZholaushyApp());
}

class ZholaushyApp extends StatelessWidget {
  const ZholaushyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final token = html.window.localStorage['token'];

    final router = GoRouter(
      initialLocation: token != null ? '/home' : '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      ],
    );

    return MaterialApp.router(
      title: 'Жолаушы',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
