import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../fcm_service.dart';

const String _regApiBase = 'http://localhost:8000/api/v1';

class RegisterScreen extends StatefulWidget {
  final String phone;
  final String code;
  final String mode; // 'passenger' | 'driver'
  const RegisterScreen({
    super.key,
    required this.phone,
    required this.code,
    this.mode = 'passenger',
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Dio().post(
        '$_regApiBase/auth/verify-otp',
        queryParameters: {
          'phone': widget.phone,
          'code':  widget.code,
          'name':  name,
          'role':  widget.mode,
        },
      );
      final token = res.data['access_token'] as String;
      html.window.localStorage['token'] = token;
      html.window.localStorage['mode']  = widget.mode;
      html.window.localStorage['name']  = name;
      registerFcmToken(token);

      if (widget.mode == 'driver') {
        // Новый водитель — сразу на ввод данных машины
        if (mounted) context.go('/car-info');
      } else {
        if (mounted) context.go('/home');
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail'] ?? 'Ошибка регистрации';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDriver = widget.mode == 'driver';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Center(child: Column(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(18)),
                    child: Icon(
                      isDriver ? Icons.directions_car_outlined : Icons.person_add_outlined,
                      color: Colors.white, size: 36,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Создать аккаунт',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Номер ${widget.phone} подтверждён',
                      style: TextStyle(color: Colors.grey[600])),
                  if (isDriver) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Режим: Водитель',
                          style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ])),

                const SizedBox(height: 32),

                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Имя и фамилия',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  onSubmitted: (_) => _register(),
                ),
                const SizedBox(height: 16),

                if (_error != null)
                  Container(
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
                      Expanded(child: Text(_error!,
                          style: TextStyle(color: Colors.red[700], fontSize: 13))),
                    ]),
                  ),

                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Зарегистрироваться'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
