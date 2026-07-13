import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../local_store.dart';
import '../fcm_service.dart';
import '../config.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  String  _mode    = 'passenger';
  int     _step    = 1;
  bool    _loading = false;
  String? _error;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _codeFocus = FocusNode();

  // 4 контроллера для OTP-боксов
  final _otpCtrls  = List.generate(4, (_) => TextEditingController());
  final _otpFocus  = List.generate(4, (_) => FocusNode());

  late final AnimationController _cardCtrl;
  late final Animation<Offset>   _cardSlide;
  late final Animation<double>   _cardFade;

  String get _fullPhone => '+77${_phoneCtrl.text.trim()}';
  String get _otpCode   => _otpCtrls.map((c) => c.text).join();

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
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  // ── Логика (не меняется) ──────────────────────────────────────────────────

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      setState(() => _error = 'Введите 9 цифр после +7 7');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Dio().post('$kApiBase/auth/send-otp', queryParameters: {'phone': _fullPhone});
      setState(() { _step = 2; _loading = false; });
      Future.delayed(const Duration(milliseconds: 100), () => _otpFocus[0].requestFocus());
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail'] ?? 'Ошибка отправки кода';
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();
    final code = _otpCode;
    if (code.length != 4) {
      setState(() => _error = 'Введите 4-значный код');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Dio().post(
        '$kApiBase/auth/verify-otp',
        queryParameters: {'phone': _fullPhone, 'code': code, 'role': _mode},
      );
      await _saveAndNavigate(res.data['access_token'] as String);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      if (detail == 'Новый пользователь — укажите имя') {
        if (mounted) context.go('/register', extra: {'phone': _fullPhone, 'code': code, 'mode': _mode});
      } else {
        setState(() { _error = detail ?? 'Неверный код'; _loading = false; });
      }
    }
  }

  Future<void> _saveAndNavigate(String token) async {
    LocalStore.setString('token', token);
    LocalStore.setString('mode', _mode);
    try {
      final me = await Dio().get('$kApiBase/auth/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      final name = me.data['name'] as String? ?? '';
      if (name.isNotEmpty) LocalStore.setString('name', name);
    } catch (_) {}
    registerFcmToken(token);
    if (_mode == 'passenger') {
      if (mounted) context.go('/home');
    } else {
      await _checkDriverProfile(token);
    }
  }

  Future<void> _checkDriverProfile(String token) async {
    try {
      final res = await Dio().get('$kApiBase/drivers/profile',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      final profile = res.data['data'];
      if (mounted) {
        context.go(profile['is_verified'] == true ? '/driver-home' : '/pending');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        if (mounted) context.go('/car-info');
      } else {
        setState(() { _error = 'Ошибка проверки профиля'; _loading = false; });
      }
    }
  }

  void _goBack() => setState(() {
    _step = 1;
    _error = null;
    for (final c in _otpCtrls) c.clear();
  });

  // ── OTP ввод по боксам ───────────────────────────────────────────────────

  void _onOtpInput(String val, int idx) {
    if (val.length > 1) {
      // Вставка всех 4 цифр сразу
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 4 && i < digits.length; i++) {
        _otpCtrls[i].text = digits[i];
      }
      if (digits.length >= 4) _verifyCode();
      return;
    }
    if (val.isNotEmpty && idx < 3) {
      _otpFocus[idx + 1].requestFocus();
    }
    if (_otpCode.length == 4) _verifyCode();
  }

  void _onOtpBack(int idx) {
    if (_otpCtrls[idx].text.isEmpty && idx > 0) {
      _otpCtrls[idx - 1].clear();
      _otpFocus[idx - 1].requestFocus();
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDriver = _mode == 'driver';

    return Theme(
      data: buildAppTheme(),
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
        children: [

          // ── Тёмный верх с брендингом ──
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.42,
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: kGradientVertical),
              child: Stack(children: [
                CustomPaint(painter: _LoginOrnamentPainter(), size: Size(size.width, size.height * 0.42)),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Иконка в круге
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(isDriver),
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: Icon(
                            isDriver ? Icons.directions_car_rounded : Icons.person_rounded,
                            color: Colors.white, size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Colors.white, kTeal],
                        ).createShader(b),
                        child: const Text(
                          'ZHOLAUSHY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDriver ? 'Режим водителя' : 'Режим пассажира',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ── Белая карточка снизу ──
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Тоггл (только шаг 1)
                          if (_step == 1) ...[
                            _ModeToggle(
                              selected: _mode,
                              onChanged: (v) => setState(() => _mode = v),
                            ),
                            const SizedBox(height: 28),
                          ],

                          // Заголовок
                          Text(
                            _step == 1 ? 'Введите номер' : 'Введите код',
                            style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800, color: kText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _step == 1
                                ? 'Отправим SMS с кодом подтверждения'
                                : 'Код отправлен на $_fullPhone',
                            style: const TextStyle(fontSize: 14, color: kSubtext),
                          ),
                          const SizedBox(height: 24),

                          // Шаг 1: телефон
                          if (_step == 1) ...[
                            _PhoneField(controller: _phoneCtrl, onSubmit: _sendCode),
                            const SizedBox(height: 8),
                            if (_error != null) _ErrorBox(message: _error!),
                            const SizedBox(height: 4),
                            _GradientButton(
                              label: 'Получить код',
                              loading: _loading,
                              onTap: _sendCode,
                            ),
                          ]

                          // Шаг 2: OTP
                          else ...[
                            _OtpRow(
                              controllers: _otpCtrls,
                              focusNodes: _otpFocus,
                              onInput: _onOtpInput,
                              onBack: _onOtpBack,
                            ),
                            const SizedBox(height: 8),
                            if (_error != null) _ErrorBox(message: _error!),
                            const SizedBox(height: 4),
                            _GradientButton(
                              label: 'Войти',
                              loading: _loading,
                              onTap: _verifyCode,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: _goBack,
                                child: Text(
                                  '← Изменить номер',
                                  style: TextStyle(color: kNavy.withOpacity(0.6), fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
      ),
    );
  }
}

// ─── Тоггл Пассажир / Водитель ───────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ModeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE3F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _tab('Пассажир', Icons.person_rounded, 'passenger'),
        _tab('Водитель', Icons.directions_car_rounded, 'driver'),
      ]),
    );
  }

  Widget _tab(String label, IconData icon, String value) {
    final active = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: active ? kGradient : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [BoxShadow(color: kNavy.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: active ? Colors.white : kSubtext),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : kSubtext,
              fontSize: 14,
            )),
          ]),
        ),
      ),
    );
  }
}

// ─── Поле телефона ───────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  const _PhoneField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardC,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divC),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: context.divC)),
          ),
          child: Text('+7 7', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: context.iconC,
          )),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            onSubmitted: (_) => onSubmit(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.textC),
            decoration: InputDecoration(
              hintText: 'XX XXX XX XX',
              hintStyle: TextStyle(color: context.subC),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── 4 OTP бокса ─────────────────────────────────────────────────────────────

class _OtpRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(String, int) onInput;
  final void Function(int) onBack;
  const _OtpRow({
    required this.controllers,
    required this.focusNodes,
    required this.onInput,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (i) => _OtpBox(
        controller: controllers[i],
        focusNode: focusNodes[i],
        onChanged: (v) => onInput(v, i),
        onBackspace: () => onBack(i),
      )),
    );
  }
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 68, height: 72,
      decoration: BoxDecoration(
        color: _focused ? kNavy.withOpacity(0.05) : kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? kTeal : filled ? kNavy.withOpacity(0.3) : const Color(0xFFDDE3F0),
          width: _focused ? 2 : 1.5,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: kTeal.withOpacity(0.15), blurRadius: 12)]
            : null,
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.backspace &&
              widget.controller.text.isEmpty) {
            widget.onBackspace();
          }
        },
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          maxLength: 1,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kNavy),
          decoration: const InputDecoration(
            counterText: '',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: widget.onChanged,
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
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5,
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

class _LoginOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    void arc(Offset o, double r, double rot) {
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(rot);
      for (final s in [1.0, 0.6, 0.32]) {
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * s), 0, pi / 2, false, p);
      }
      canvas.restore();
    }

    final r = size.width * 0.25;
    arc(Offset.zero,         r,         0);
    arc(Offset(size.width, 0), r, pi / 2);
    arc(Offset(0, size.height), r,    -pi / 2);
    arc(Offset(size.width, size.height), r, pi);
  }

  @override
  bool shouldRepaint(_) => false;
}
