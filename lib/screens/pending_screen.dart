import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../config.dart';
import '../theme.dart';
import '../app_state.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  bool _checking = false;
  String? _rejectionReason;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  String? _getToken() => html.window.localStorage['token'];

  Future<void> _check() async {
    setState(() => _checking = true);
    final token = _getToken();
    if (token == null) { if (mounted) context.go('/login'); return; }
    try {
      final res = await Dio().get(
        '$kApiBase/drivers/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final profile = res.data['data'];
      if (profile['is_verified'] == true) {
        if (mounted) context.go('/driver-home');
        return;
      }
      setState(() {
        _rejectionReason = profile['rejection_reason'];
        _loaded = true;
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        if (mounted) context.go('/car-info');
        return;
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _logout() {
    html.window.localStorage.remove('token');
    html.window.localStorage.remove('mode');
    html.window.localStorage['theme'] = 'light';
    AppState.themeNotifier.value = ThemeMode.light;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = _rejectionReason != null && _rejectionReason!.isNotEmpty;

    return Scaffold(
      backgroundColor: context.bgC,
      body: BodyOrnament(child: _checking && !_loaded
          ? const Center(child: CircularProgressIndicator(color: kNavy))
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: isRejected ? Colors.red[50] : Colors.orange[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                          size: 52,
                          color: isRejected ? Colors.red[400] : Colors.orange[400],
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(
                        isRejected ? 'Заявка отклонена' : 'Ожидает проверки',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textC),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      if (isRejected) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.info_outline, color: Colors.red[600], size: 18),
                              const SizedBox(width: 8),
                              Text('Причина отказа:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red[700], fontSize: 13)),
                            ]),
                            const SizedBox(height: 8),
                            Text(_rejectionReason!, style: TextStyle(color: Colors.red[800], fontSize: 14)),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Исправьте данные автомобиля и отправьте заявку повторно.',
                          style: TextStyle(color: context.subC, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Text(
                          'Ваша заявка передана администратору.\nОбычно проверка занимает несколько часов.',
                          style: TextStyle(color: context.subC, fontSize: 14, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Нажмите "Обновить" — мы проверим статус.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 32),

                      if (isRejected)
                        GestureDetector(
                          onTap: () => context.go('/car-info?update=true'),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: kGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Изменить данные машины',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                            ]),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _checking ? null : _check,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: _checking ? null : kGradient,
                              color: _checking ? Colors.grey[300] : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _checking
                                  ? const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.refresh, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Обновить статус',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                    ]),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: _logout,
                        child: Text('Выйти', style: TextStyle(color: context.subC)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ));
  }
}
