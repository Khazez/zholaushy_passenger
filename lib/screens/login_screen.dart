import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String _apiBase = 'http://localhost:8000/api/v1';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _step = 1;
  bool _loading = false;
  String? _error;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  String get _fullPhone => '+77${_phoneCtrl.text.trim()}';

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
        queryParameters: {'phone': _fullPhone, 'code': code},
      );
      html.window.localStorage['token'] = res.data['access_token'];
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      if (detail == 'Новый пользователь — укажите имя') {
        if (mounted) {
          context.go('/register', extra: {'phone': _fullPhone, 'code': code});
        }
      } else {
        setState(() {
          _error = detail ?? 'Неверный код';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('Жолаушы',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _step == 1 ? 'Введите номер телефона' : 'Введите код из СМС',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

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
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  ElevatedButton(
                    onPressed: _loading ? null : _sendCode,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Получить код'),
                  ),
                ] else ...[
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
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
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
}
