import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../fcm_service.dart';

const String _apiBase = 'http://localhost:8000/api/v1';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _mode = 'passenger';
  int    _step = 1; // 1 = телефон, 2 = код
  bool   _loading = false;
  String? _error;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();

  String get _fullPhone => '+77${_phoneCtrl.text.trim()}';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      setState(() => _error = 'Введите 9 цифр после +7 7');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Dio().post(
        '$_apiBase/auth/send-otp',
        queryParameters: {'phone': _fullPhone},
      );
      setState(() { _step = 2; _loading = false; });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail'] ?? 'Ошибка отправки кода';
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 4) {
      setState(() => _error = 'Введите 4-значный код');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Dio().post(
        '$_apiBase/auth/verify-otp',
        queryParameters: {'phone': _fullPhone, 'code': code, 'role': _mode},
      );
      final token = res.data['access_token'] as String;
      await _saveAndNavigate(token);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      if (detail == 'Новый пользователь — укажите имя') {
        if (mounted) {
          context.go('/register', extra: {'phone': _fullPhone, 'code': code, 'mode': _mode});
        }
      } else {
        setState(() {
          _error = detail ?? 'Неверный код';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveAndNavigate(String token) async {
    html.window.localStorage['token'] = token;
    html.window.localStorage['mode']  = _mode;

    // Сохраняем имя
    try {
      final me = await Dio().get(
        '$_apiBase/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final name = me.data['name'] as String? ?? '';
      if (name.isNotEmpty) html.window.localStorage['name'] = name;
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
      final res = await Dio().get(
        '$_apiBase/drivers/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final profile = res.data['data'];
      if (mounted) {
        if (profile['is_verified'] == true) {
          context.go('/driver-home');
        } else {
          context.go('/pending');
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        if (mounted) context.go('/car-info');
      } else {
        if (mounted) setState(() { _error = 'Ошибка проверки профиля водителя'; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final isDriver = _mode == 'driver';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Логотип
                Center(child: Column(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20)),
                    child: Icon(
                      isDriver ? Icons.directions_car_outlined : Icons.person_outlined,
                      color: Colors.white, size: 40,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Жолаушы',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Межгородские поездки',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ])),

                const SizedBox(height: 32),

                // Тоггл Пассажир / Водитель (только на шаге 1)
                if (_step == 1) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(children: [
                      _toggleTab('Пассажир', Icons.person_outlined,         'passenger', primary),
                      _toggleTab('Водитель',  Icons.directions_car_outlined, 'driver',    primary),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],

                // Шаг 1: телефон
                if (_step == 1) ...[
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixText: '+7 7',
                      prefixStyle: TextStyle(fontSize: 16, color: Colors.black87),
                      hintText: 'XX XXX XX XX',
                      labelText: 'Номер телефона',
                    ),
                    onSubmitted: (_) => _sendCode(),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) _errorBox(_error!),
                  ElevatedButton(
                    onPressed: _loading ? null : _sendCode,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Получить код'),
                  ),
                ]
                // Шаг 2: код
                else ...[
                  Text('Код отправлен на $_fullPhone',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, letterSpacing: 16),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '_ _ _ _',
                    ),
                    autofocus: true,
                    onChanged: (v) { if (v.length == 4) _verifyCode(); },
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) _errorBox(_error!),
                  ElevatedButton(
                    onPressed: _loading ? null : _verifyCode,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Войти'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _step = 1;
                      _error = null;
                      _codeCtrl.clear();
                    }),
                    child: const Text('Изменить номер'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleTab(String label, IconData icon, String value, Color primary) {
    final selected = _mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: selected ? primary : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? primary : Colors.grey[500],
              fontSize: 14,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.red[50],
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red[200]!),
    ),
    child: Row(children: [
      Icon(Icons.error_outline, color: Colors.red[600], size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: TextStyle(color: Colors.red[700], fontSize: 13))),
    ]),
  );
}
