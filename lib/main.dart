import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'fcm_service.dart';
import 'app_state.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';

const _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyC5k6vD8moo1cF8ewdF3H-RLx8tslz9a5c',
  appId: '1:1054390633030:web:76ec102fd5b22f0d2a0047',
  messagingSenderId: '1054390633030',
  projectId: 'taxi-b163c',
  authDomain: 'taxi-b163c.firebaseapp.com',
  storageBucket: 'taxi-b163c.firebasestorage.app',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _firebaseOptions);
  final savedToken = html.window.localStorage['token'];
  if (savedToken != null) registerFcmToken(savedToken);
  runApp(const ZholaushyApp());
}

class ZholaushyApp extends StatefulWidget {
  const ZholaushyApp({super.key});

  @override
  State<ZholaushyApp> createState() => _ZholaushyAppState();
}

class _ZholaushyAppState extends State<ZholaushyApp> {
  void _rebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppState.themeNotifier.value = AppState.parseTheme(html.window.localStorage['theme'] ?? 'system');
    AppState.langNotifier.value  = html.window.localStorage['lang'] ?? 'ru';
    AppState.themeNotifier.addListener(_rebuild);
    AppState.langNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppState.themeNotifier.removeListener(_rebuild);
    AppState.langNotifier.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = html.window.localStorage['token'];

    final router = GoRouter(
      initialLocation: token != null ? '/home' : '/login',
      routes: [
        GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/register',
          builder: (_, state) {
            final extra = state.extra as Map<String, String>?;
            return RegisterScreen(
              phone: extra?['phone'] ?? '',
              code:  extra?['code']  ?? '',
            );
          },
        ),
        GoRoute(path: '/home',    builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      ],
    );

    const seed = Color(0xFF1A73E8);

    final inputTheme = InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
    final buttonTheme = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

    return MaterialApp.router(
      title: 'Жолаушы',
      debugShowCheckedModeBanner: false,
      themeMode: AppState.themeNotifier.value,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
        inputDecorationTheme: inputTheme,
        elevatedButtonTheme: buttonTheme,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
        inputDecorationTheme: inputTheme,
        elevatedButtonTheme: buttonTheme,
      ),

      routerConfig: router,
    );
  }
}
