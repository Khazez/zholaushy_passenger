import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _ornCtrl;
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _bgFade;
  late final Animation<double> _ornScale;
  late final Animation<double> _ornFade;
  late final Animation<double> _ornRotate;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _bgFade = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn);

    _ornCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _ornScale  = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ornCtrl, curve: Curves.elasticOut),
    );
    _ornFade   = CurvedAnimation(parent: _ornCtrl, curve: Curves.easeOut);
    _ornRotate = Tween<double>(begin: -pi / 12, end: 0.0).animate(
      CurvedAnimation(parent: _ornCtrl, curve: Curves.easeOut),
    );

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoFade  = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );

    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _ornCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    final token = html.window.localStorage['token'];
    final mode  = html.window.localStorage['mode'];
    if (token != null && token.isNotEmpty) {
      context.go(mode == 'driver' ? '/driver-home' : '/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ornCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final ornSize = (w * 0.52).clamp(160.0, 260.0);

    return Scaffold(
      body: FadeTransition(
        opacity: _bgFade,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Фон ──
            const DecoratedBox(decoration: BoxDecoration(gradient: kGradientVertical)),

            // ── Угловые орнаменты (фоновый слой) ──
            CustomPaint(painter: _CornerOrnamentPainter()),

            // ── Центральный блок ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Пульс-свечение + центральный орнамент
                  AnimatedBuilder(
                    animation: Listenable.merge([_pulse, _ornCtrl]),
                    builder: (_, __) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Свечение
                          Container(
                            width: ornSize + 60,
                            height: ornSize + 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: kTeal.withOpacity(0.22 * _pulse.value),
                                  blurRadius: 70,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),

                          // Казахский орнамент
                          Transform.rotate(
                            angle: _ornRotate.value,
                            child: Transform.scale(
                              scale: _ornScale.value,
                              child: Opacity(
                                opacity: _ornFade.value,
                                child: CustomPaint(
                                  size: Size(ornSize, ornSize),
                                  painter: _KazakhEmblemPainter(pulse: _pulse.value),
                                ),
                              ),
                            ),
                          ),

                          // Иконка машины по центру
                          Transform.scale(
                            scale: _ornScale.value,
                            child: Opacity(
                              opacity: _ornFade.value,
                              child: ShaderMask(
                                shaderCallback: (b) => kGradient.createShader(b),
                                child: Icon(
                                  Icons.directions_car_rounded,
                                  size: ornSize * 0.28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Название
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Colors.white, kTeal],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(b),
                        child: const Text(
                          'ZHOLAUSHY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Казахское название
                  FadeTransition(
                    opacity: _logoFade,
                    child: Text(
                      'Ж О Л А У Ш Ы',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Разделитель
                  FadeTransition(
                    opacity: _textFade,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ornamentDot(),
                        const SizedBox(width: 8),
                        Container(
                          width: 60, height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.1), kTeal.withOpacity(0.8)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'АКТОБЕ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 60, height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kTeal.withOpacity(0.8), Colors.white.withOpacity(0.1)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ornamentDot(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Text(
                        'Қалааралық такси · Межгородские поездки',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ornamentDot() => Container(
    width: 4, height: 4,
    decoration: const BoxDecoration(color: kTeal, shape: BoxShape.circle),
  );
}

// ─── Центральный казахский эмблем ────────────────────────────────────────────

class _KazakhEmblemPainter extends CustomPainter {
  final double pulse;
  const _KazakhEmblemPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // Внешний круг
    _drawCircle(canvas, Offset(cx, cy), r * 0.96, 1.5, kTeal.withOpacity(0.6));

    // Средний круг
    _drawCircle(canvas, Offset(cx, cy), r * 0.72, 1.0, Colors.white.withOpacity(0.2));

    // Внутренний круг
    _drawCircle(canvas, Offset(cx, cy), r * 0.42, 0.8, kTeal.withOpacity(0.35));

    // 8 лепестков (казахский паттерн)
    final petalPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final px = cx + cos(angle) * r * 0.57;
      final py = cy + sin(angle) * r * 0.57;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: r * 0.28, height: r * 0.28),
        petalPaint,
      );
    }

    // 8 лучей от центра
    final rayPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 0.8;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      canvas.drawLine(
        Offset(cx + cos(angle) * r * 0.42, cy + sin(angle) * r * 0.42),
        Offset(cx + cos(angle) * r * 0.72, cy + sin(angle) * r * 0.72),
        rayPaint,
      );
    }

    // 8 звёздных точек на внешнем кольце
    final dotPaint = Paint()
      ..color = kTeal.withOpacity(0.7 * pulse)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi - pi / 8;
      canvas.drawCircle(
        Offset(cx + cos(angle) * r * 0.96, cy + sin(angle) * r * 0.96),
        3,
        dotPaint,
      );
    }

    // Ромбы между лепестками (традиционный мотив)
    final rhombusPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi + pi / 8;
      final dx = cx + cos(angle) * r * 0.83;
      final dy = cy + sin(angle) * r * 0.83;
      final s = r * 0.09;
      canvas.drawPath(
        Path()
          ..moveTo(dx, dy - s)
          ..lineTo(dx + s, dy)
          ..lineTo(dx, dy + s)
          ..lineTo(dx - s, dy)
          ..close(),
        rhombusPaint,
      );
    }
  }

  void _drawCircle(Canvas canvas, Offset c, double r, double w, Color color) {
    canvas.drawCircle(c, r, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w);
  }

  @override
  bool shouldRepaint(covariant _KazakhEmblemPainter old) => old.pulse != pulse;
}

// ─── Угловые орнаменты ───────────────────────────────────────────────────────

class _CornerOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final r = size.width * 0.22;

    _corner(canvas, paint, Offset.zero, r, 0);
    _corner(canvas, paint, Offset(size.width, 0), r, pi / 2);
    _corner(canvas, paint, Offset(0, size.height), r, -pi / 2);
    _corner(canvas, paint, Offset(size.width, size.height), r, pi);
  }

  void _corner(Canvas canvas, Paint p, Offset o, double r, double rot) {
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(rot);
    for (final scale in [1.0, 0.65, 0.38]) {
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * scale),
          0, pi / 2, false, p);
    }
    for (int i = 0; i <= 2; i++) {
      final a = (i / 2) * (pi / 2);
      canvas.drawCircle(
        Offset(cos(a) * r * 0.51, sin(a) * r * 0.51),
        r * 0.07,
        p,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}
