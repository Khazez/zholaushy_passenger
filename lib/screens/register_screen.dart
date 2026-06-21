import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String apiBase = 'http://localhost:8000/api/v1';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  Future<void> _register() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() { _loading = true; _error = null; });

  try {
    final dio = Dio();
    // Регистрация
    await dio.post(
      '$apiBase/auth/register',
      data: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    // Логин после регистрации
    final loginRes = await dio.post(
      '$apiBase/auth/login',
      data: {
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    final token = loginRes.data['access_token'];
    html.window.localStorage['token'] = token;
    if (mounted) context.go('/home');
  } on DioException catch (e) {
    final detail = e.response?.data['detail'];
    String msg;
    if (detail is List) {
      msg = detail.map((e) => e['msg'] ?? e.toString()).join(', ');
    } else {
      msg = detail?.toString() ?? 'Ошибка регистрации';
    }
    setState(() => _error = msg);
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Регистрация', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Создайте аккаунт пассажира', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Имя и фамилия',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Введите имя' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Номер телефона',
                    hintText: '+7 777 123 4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Введите номер' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Минимум 6 символов' : null,
                ),
                const SizedBox(height: 12),

                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 14))),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Создать аккаунт'),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Уже есть аккаунт?', style: TextStyle(color: Colors.grey[600])),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Войти'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
