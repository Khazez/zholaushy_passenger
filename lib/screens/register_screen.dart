import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String _regApiBase = 'http://localhost:8000/api/v1';

// Этот экран открывается только когда номер новый (пришли из login_screen с phone+code)
class RegisterScreen extends StatefulWidget {
  final String phone;
  final String code;
  const RegisterScreen({super.key, required this.phone, required this.code});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

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
          'code': widget.code,
          'name': name,
        },
      );
      html.window.localStorage['token'] = res.data['access_token'];
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail'] ?? 'Ошибка регистрации';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('Создать аккаунт',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Номер ${widget.phone} подтверждён',
                    style: TextStyle(color: Colors.grey[600])),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
