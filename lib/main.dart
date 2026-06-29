import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'fcm_service.dart';
import 'app_state.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/car_info_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/active_trip_screen.dart';

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
  GoogleFonts.config.allowRuntimeFetching = true;
  final savedToken = html.window.localStorage['token'];
  if (savedToken != null) registerFcmToken(savedToken);
  runApp(const ZholaushyApp());
}

class ZholaushyApp extends StatefulWidget {
  const ZholaushyApp({super.key});

  @override
  State<ZholaushyApp> createState() => _ZholaushyAppState();
}

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class _ZholaushyAppState extends State<ZholaushyApp> {
  late final GoRouter _router;

  void _rebuild() => setState(() {});

  void _initForegroundPush() {
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final title = msg.notification?.title ?? msg.data['title'] as String? ?? 'Уведомление';
      final body  = msg.notification?.body  ?? msg.data['body']  as String? ?? '';
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              if (body.isNotEmpty) Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF0D1F6E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _initForegroundPush();
    // Роутер создаётся один раз — пересоздание при rebuild выкидывало бы на /splash
    _router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash',      builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login',       builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/register',
          builder: (_, state) {
            final extra = state.extra as Map<String, String>? ?? {};
            return RegisterScreen(
              phone: extra['phone'] ?? '',
              code:  extra['code']  ?? '',
              mode:  extra['mode']  ?? 'passenger',
            );
          },
        ),
        GoRoute(path: '/home',        builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/history',     builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/driver-home', builder: (_, __) => const DriverHomeScreen()),
        GoRoute(
          path: '/car-info',
          builder: (_, state) {
            final isUpdate = state.uri.queryParameters['update'] == 'true';
            return CarInfoScreen(isUpdate: isUpdate);
          },
        ),
        GoRoute(path: '/pending',     builder: (_, __) => const PendingScreen()),
        GoRoute(
          path: '/active-trip',
          builder: (_, state) {
            final data = state.extra as Map<String, dynamic>? ?? {};
            return ActiveTripScreen(request: data);
          },
        ),
      ],
    );
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
    return MaterialApp.router(
      title: 'ZHOLAUSHY',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      themeMode: AppState.themeNotifier.value,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: _router,
    );
  }
}
