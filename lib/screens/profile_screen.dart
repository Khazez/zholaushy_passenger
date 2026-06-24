import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String _apiBase = 'http://localhost:8000/api/v1';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;

  String _name = '';
  String _phone = '';
  String _createdAt = '';

  late TextEditingController _nameCtrl;

  String? _getToken() => html.window.localStorage['token'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final token = _getToken();
    if (token == null) return;
    try {
      final res = await Dio().get(
        '$_apiBase/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final d = res.data;
      setState(() {
        _name = d['name'] ?? '';
        _phone = d['phone'] ?? '';
        _createdAt = _formatDate(d['created_at']);
        _nameCtrl.text = _name;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки профиля: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _save() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty || newName == _name) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      final token = _getToken();
      await Dio().patch(
        '$_apiBase/auth/me',
        data: {'name': newName},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      setState(() {
        _name = newName;
        _editing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Имя обновлено'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка сохранения'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Профиль', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(children: [

                // ── Шапка с аватаром ──
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                  child: Column(children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              _initials(_name),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Карточка данных ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(children: [

                      // Имя
                      _editing
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Имя', style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: Colors.grey[500], letterSpacing: 0.5,
                                  )),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _nameCtrl,
                                    autofocus: true,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      hintText: 'Введите имя',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: primary, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => setState(() {
                                          _editing = false;
                                          _nameCtrl.text = _name;
                                        }),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text('Отмена'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _saving ? null : _save,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: _saving
                                            ? const SizedBox(
                                                width: 18, height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2, color: Colors.white,
                                                ),
                                              )
                                            : const Text('Сохранить'),
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            )
                          : _infoRow(
                              icon: Icons.person_outline,
                              label: 'Имя',
                              value: _name,
                              primary: primary,
                              trailing: IconButton(
                                icon: Icon(Icons.edit_outlined, size: 20, color: primary),
                                onPressed: () => setState(() => _editing = true),
                              ),
                            ),

                      Divider(height: 1, indent: 60, color: Colors.grey[100]),

                      // Телефон
                      _infoRow(
                        icon: Icons.phone_outlined,
                        label: 'Телефон',
                        value: _phone,
                        primary: primary,
                        subtitle: 'Изменить номер нельзя',
                      ),

                      if (_createdAt.isNotEmpty) ...[
                        Divider(height: 1, indent: 60, color: Colors.grey[100]),
                        _infoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Дата регистрации',
                          value: _createdAt,
                          primary: primary,
                        ),
                      ],
                    ]),
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color primary,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: Colors.grey[500], letterSpacing: 0.4,
            )),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500,
            )),
            if (subtitle != null)
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ]),
        ),
        if (trailing != null) trailing,
      ]),
    );
  }
}
