import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

// ─── Цвета тёмной темы ───────────────────────────────────────────────────────

const kDarkBg      = Color(0xFF0F1729);
const kDarkCard    = Color(0xFF1A2744);
const kDarkText    = Color(0xFFE8EDF8);
const kDarkSubtext = Color(0xFF8899BB);

TextTheme _buildTextTheme(TextTheme base) => GoogleFonts.interTextTheme(base);

final _interFamily = GoogleFonts.inter().fontFamily;

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _interFamily,
    colorScheme: const ColorScheme.dark(
      primary: kTeal,
      secondary: kTeal,
      surface: kDarkCard,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: kDarkText,
    ),
    scaffoldBackgroundColor: kDarkBg,
    cardTheme: CardThemeData(
      color: kDarkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        backgroundColor: kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDarkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3A60)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3A60)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kTeal, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    textTheme: _buildTextTheme(const TextTheme(
      headlineLarge: TextStyle(color: kDarkText, fontWeight: FontWeight.w800, fontSize: 28),
      headlineMedium: TextStyle(color: kDarkText, fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge: TextStyle(color: kDarkText, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: TextStyle(color: kDarkText, fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge: TextStyle(color: kDarkText, fontSize: 15),
      bodyMedium: TextStyle(color: kDarkSubtext, fontSize: 13),
    )),
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: _interFamily,
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
    textTheme: _buildTextTheme(const TextTheme(
      headlineLarge: TextStyle(color: kText, fontWeight: FontWeight.w800, fontSize: 28),
      headlineMedium: TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge: TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge: TextStyle(color: kText, fontSize: 15),
      bodyMedium: TextStyle(color: kSubtext, fontSize: 13),
    )),
  );
}

// ─── AppBar с орнаментом ─────────────────────────────────────────────────────

// AppBar с казахским орнаментом — flexibleSpace
class AppBarOrnament extends StatelessWidget {
  const AppBarOrnament({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AppBarOrnamentPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _AppBarOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Градиент фон
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = kGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      ),
    );

    final p = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final dot = Paint()
      ..color = Colors.white.withOpacity(0.40)
      ..style = PaintingStyle.fill;

    final r = size.height * 1.4;

    void kazakhCorner(Offset origin, double rot) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(rot);
      // Три дуги
      for (final s in [1.0, 0.62, 0.36]) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r * s),
          0, pi / 2, false, p,
        );
      }
      // Ромб на пересечении
      final d = r * 0.36;
      final ds = r * 0.07;
      canvas.drawPath(
        Path()
          ..moveTo(d, 0)..lineTo(d + ds, ds)
          ..lineTo(d, ds * 2)..lineTo(d - ds, ds)..close(),
        p,
      );
      // Точки вдоль внешней дуги
      for (int i = 0; i <= 3; i++) {
        final a = (i / 3) * (pi / 2);
        canvas.drawCircle(
          Offset(cos(a) * r, sin(a) * r), 2.5, dot,
        );
      }
      canvas.restore();
    }

    kazakhCorner(Offset.zero, 0);
    kazakhCorner(Offset(size.width, 0), pi / 2);
    kazakhCorner(Offset(0, size.height), -pi / 2);
    kazakhCorner(Offset(size.width, size.height), pi);
  }

  @override
  bool shouldRepaint(_) => false;
}

// Казахский орнамент поверх тела экрана
class BodyOrnament extends StatelessWidget {
  final Widget child;
  const BodyOrnament({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final color = context.iconC;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: CustomPaint(
            painter: _BodyOrnamentPainter(color),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _BodyOrnamentPainter extends CustomPainter {
  final Color color;
  const _BodyOrnamentPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final dot = Paint()
      ..color = color.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final r = size.width * 0.26;

    void kazakhCorner(Offset origin, double rot) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(rot);
      for (final s in [1.0, 0.62, 0.36]) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r * s),
          0, pi / 2, false, p,
        );
      }
      // Ромб
      final d = r * 0.36;
      final ds = r * 0.06;
      canvas.drawPath(
        Path()
          ..moveTo(d, 0)..lineTo(d + ds, ds)
          ..lineTo(d, ds * 2)..lineTo(d - ds, ds)..close(),
        p,
      );
      // Точки
      for (int i = 0; i <= 4; i++) {
        final a = (i / 4) * (pi / 2);
        canvas.drawCircle(Offset(cos(a) * r, sin(a) * r), 2.0, dot);
      }
      canvas.restore();
    }

    kazakhCorner(Offset.zero, 0);
    kazakhCorner(Offset(size.width, 0), pi / 2);
    kazakhCorner(Offset(0, size.height), -pi / 2);
    kazakhCorner(Offset(size.width, size.height), pi);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Динамические цвета (светлая / тёмная тема) ──────────────────────────────

extension AppColors on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;
  Color get bgC      => _dark ? kDarkBg   : kBg;
  Color get cardC    => _dark ? kDarkCard  : kCard;
  Color get textC    => _dark ? kDarkText  : kText;
  Color get subC     => _dark ? kDarkSubtext : kSubtext;
  Color get iconBgC  => _dark ? kTeal.withOpacity(0.15) : kNavy.withOpacity(0.10);
  Color get iconC    => _dark ? kTeal  : kNavy;
  Color get shadowC  => _dark ? Colors.black.withOpacity(0.25) : kNavy.withOpacity(0.06);
  Color get divC     => _dark ? Colors.white.withOpacity(0.08) : const Color(0xFFF0F0F0);
}
