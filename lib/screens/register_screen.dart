import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../local_store.dart';
import '../fcm_service.dart';
import '../config.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  final String phone;
  final String code;
  final String mode;
  const RegisterScreen({
    super.key,
    required this.phone,
    required this.code,
    this.mode = 'passenger',
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  bool    _loading = false;
  String? _error;

  late final AnimationController _cardCtrl;
  late final Animation<Offset>   _cardSlide;
  late final Animation<double>   _cardFade;

  bool get _isDriver => widget.mode == 'driver';

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardCtrl.forward();
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Логика (не меняется) ──────────────────────────────────────────────────

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите ваше имя');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Dio().post(
        '$kApiBase/auth/verify-otp',
        queryParameters: {
          'phone': widget.phone,
          'code':  widget.code,
          'name':  name,
          'role':  widget.mode,
        },
      );
      final token = res.data['access_token'] as String;
      LocalStore.setString('token', token);
      LocalStore.setString('mode', widget.mode);
      LocalStore.setString('name', name);
      registerFcmToken(token);
      if (mounted) context.go(_isDriver ? '/car-info' : '/home');
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail'] ?? 'Ошибка регистрации';
        _loading = false;
      });
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Theme(
      data: buildAppTheme(),
      child: Scaffold(
      body: Stack(
        children: [

          // ── Тёмный верх ──
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.42,
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: kGradientVertical),
              child: Stack(children: [
                CustomPaint(
                  painter: _RegOrnamentPainter(),
                  size: Size(size.width, size.height * 0.42),
                ),
                // Кнопка назад
                Positioned(
                  top: 12, left: 8,
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // Иконка с галочкой подтверждения
                      Stack(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                            ),
                            child: Icon(
                              _isDriver ? Icons.directions_car_rounded : Icons.person_add_rounded,
                              color: Colors.white, size: 36,
                            ),
                          ),
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: kTeal,
                                shape: BoxShape.circle,
                                border: Border.all(color: kNavy, width: 2),
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Colors.white, kTeal],
                        ).createShader(b),
                        child: const Text(
                          'ДОБРО ПОЖАЛОВАТЬ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Телефон подтверждён
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.phone_rounded, color: kTeal, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            widget.phone,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: kTeal, size: 14),
                        ]),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ── Белая карточка ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.65,
            child: SlideTransition(
              position: _cardSlide,
              child: FadeTransition(
                opacity: _cardFade,
                child: Container(
                  decoration: const BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                    boxShadow: [
                      BoxShadow(color: Color(0x1A0D1F6E), blurRadius: 30, offset: Offset(0, -8)),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Бейдж режима
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: kGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              _isDriver ? Icons.directions_car_rounded : Icons.person_rounded,
                              color: Colors.white, size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isDriver ? 'Водитель' : 'Пассажир',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Как вас зовут?',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kText),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Это имя увидят другие пользователи',
                          style: TextStyle(fontSize: 14, color: kSubtext),
                        ),

                        const SizedBox(height: 24),

                        // Поле имени
                        Container(
                          decoration: BoxDecoration(
                            color: kBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDDE3F0)),
                          ),
                          child: TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            autofocus: true,
                            onSubmitted: (_) => _register(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kText),
                            decoration: InputDecoration(
                              hintText: 'Например: Алибек Сейткали',
                              hintStyle: const TextStyle(color: kSubtext),
                              prefixIcon: const Icon(Icons.person_rounded, color: kTeal, size: 22),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        if (_error != null) _ErrorBox(message: _error!),

                        const SizedBox(height: 4),

                        _GradientButton(
                          label: 'Создать аккаунт',
                          loading: _loading,
                          onTap: _register,
                        ),

                        const SizedBox(height: 20),

                        // Подсказка для водителя
                        if (_isDriver)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kTeal.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: kTeal.withOpacity(0.2)),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.info_outline_rounded, color: kTeal, size: 18),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'После регистрации нужно будет указать данные автомобиля и пройти верификацию',
                                  style: TextStyle(color: kSubtext, fontSize: 13, height: 1.4),
                                ),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Кнопка с градиентом ─────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          gradient: loading ? null : kGradient,
          color: loading ? const Color(0xFFDDE3F0) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading ? null : [
            BoxShadow(color: kNavy.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: kNavy))
              : Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5,
                )),
        ),
      ),
    );
  }
}

// ─── Блок ошибки ─────────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13))),
      ]),
    );
  }
}

// ─── Орнамент в шапке ────────────────────────────────────────────────────────

class _RegOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final r = size.width * 0.25;

    void arc(Offset o, double rot) {
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(rot);
      for (final s in [1.0, 0.6, 0.32]) {
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * s), 0, pi / 2, false, p);
      }
      canvas.restore();
    }

    arc(Offset.zero,                          0);
    arc(Offset(size.width, 0),          pi / 2);
    arc(Offset(0, size.height),        -pi / 2);
    arc(Offset(size.width, size.height), pi);
  }

  @override
  bool shouldRepaint(_) => false;
}
