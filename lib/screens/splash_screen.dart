import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../local_store.dart';
import '../theme.dart';

const _kTotalMs = 2050;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _dotsOpacity;

  static const _word = 'ZHOLAUSHY';

  Interval _letterInterval(int i) {
    final startMs = 620 + i * 60;
    final endMs = startMs + 400;
    return Interval(
      startMs / _kTotalMs,
      (endMs / _kTotalMs).clamp(0.0, 1.0),
      curve: const Cubic(0.2, 0.9, 0.3, 1.0),
    );
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTotalMs),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.42, curve: Cubic(0.2, 1.4, 0.4, 1.0)),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _subtitleOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.62, 0.80, curve: Curves.easeOut),
    );
    _dotsOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.756, 1.0, curve: Curves.easeOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _ctrl.forward();
    await Future.delayed(const Duration(milliseconds: _kTotalMs + 300));
    if (!mounted) return;
    final token = LocalStore.getString('token');
    final mode = LocalStore.getString('mode');
    if (token != null && token.isNotEmpty) {
      context.go(mode == 'driver' ? '/driver-home' : '/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoOpacity,
      child: ScaleTransition(
        scale: _logoScale,
        child: Image.asset(
          'assets/images/zholaushy_icon.png',
          width: 132,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _word.length; i++)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final t = _letterInterval(i).transform(_ctrl.value);
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - t.clamp(0.0, 1.0))),
                  child: child,
                ),
              );
            },
            child: Text(
              _word[i],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
      ],
    );
  }

  double _dotIntensity(double t) {
    // peak at 40% of the cycle, matches the CSS loading-dot bounce
    if (t < 0.4) {
      final k = Curves.easeOut.transform(t / 0.4);
      return 0.25 + (1.0 - 0.25) * k;
    }
    final k = Curves.easeIn.transform((t - 0.4) / 0.6);
    return 1.0 - (1.0 - 0.25) * k;
  }

  Widget _buildDots() {
    return FadeTransition(
      opacity: _dotsOpacity,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Builder(builder: (context) {
                  final phase = (i * 0.15) / 1.2;
                  final t = (_pulseCtrl.value + phase) % 1.0;
                  final intensity = _dotIntensity(t);
                  return Opacity(
                    opacity: intensity,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * intensity,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: kGradientVertical),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 18),
                  _buildWordmark(),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: Text(
                      'Қалааралық такси · Межгородские поездки',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Center(child: _buildDots()),
            ),
          ],
        ),
      ),
    );
  }
}
