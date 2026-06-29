import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../app_state.dart';
import '../config.dart';
import '../theme.dart';

void _openUrl(String url) => html.window.open(url, '_blank');

// ─── СЛУЖБА ПОДДЕРЖКИ ────────────────────────────────────────────────────────

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _msgCtrl = TextEditingController();

  String _phone    = '';
  String _whatsApp = '';
  String _telegram = '';
  bool   _loaded   = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final raw = await html.HttpRequest.getString('$kApiBase/settings/public');
      final list = jsonDecode(raw) as List<dynamic>;
      final map = {for (final s in list) s['key'] as String: s['value'] as String};
      if (mounted) {
        setState(() {
          _phone    = map['support_phone']    ?? '';
          _whatsApp = map['support_whatsapp'] ?? '';
          _telegram = map['support_telegram'] ?? '';
          _loaded   = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) return;
    final encoded = Uri.encodeComponent(msg);
    _openUrl('https://wa.me/${_whatsApp.replaceAll('+', '')}?text=$encoded');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Служба поддержки', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        flexibleSpace: const AppBarOrnament(),
      ),
      body: BodyOrnament(child: !_loaded
          ? const Center(child: CircularProgressIndicator(color: kNavy))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _SectionCard(children: [
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Телефон',
              value: _phone.isEmpty ? '—' : _phone,
              onTap: _phone.isEmpty ? null : () => _openUrl('tel:$_phone'),
            ),
            Divider(height: 1, indent: 56, color: context.divC),
            const _ContactRow(
              icon: Icons.access_time_outlined,
              label: 'Режим работы',
              value: 'Пн–Вс, 08:00 – 22:00',
            ),
          ]),

          const SizedBox(height: 16),

          Text('Написать нам', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.subC, letterSpacing: 0.4)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MessengerBtn(
              label: 'WhatsApp', color: const Color(0xFF25D366), icon: Icons.chat_bubble_outline,
              onTap: () => _openUrl('https://wa.me/${_whatsApp.replaceAll('+', '')}'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _MessengerBtn(
              label: 'Telegram', color: const Color(0xFF2CA5E0), icon: Icons.send_outlined,
              onTap: () => _openUrl('https://t.me/$_telegram'),
            )),
          ]),

          const SizedBox(height: 24),

          Text('Написать в WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.subC, letterSpacing: 0.4)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(color: context.cardC, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: context.shadowC, blurRadius: 12, offset: const Offset(0, 4))]),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                controller: _msgCtrl,
                maxLines: 5,
                style: TextStyle(color: context.textC),
                decoration: InputDecoration(
                  hintText: 'Опишите вашу проблему или вопрос...',
                  hintStyle: TextStyle(color: context.subC, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kTeal, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.divC)),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Открыть в WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      )),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: context.iconBgC, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: context.iconC, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: context.subC, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: onTap != null ? kTeal : context.textC)),
          ])),
          if (onTap != null) Icon(Icons.chevron_right, color: context.subC, size: 20),
        ]),
      ),
    );
  }
}

class _MessengerBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _MessengerBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14,
          )),
        ]),
      ),
    );
  }
}

// ─── НАСТРОЙКИ ───────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  late String _lang;
  late String _themeKey;

  static const _langs = [
    ('kz', '🇰🇿', 'Қазақша'),
    ('ru', '🇷🇺', 'Русский'),
    ('en', '🇬🇧', 'English'),
  ];

  static const _themes = [
    ('light',  Icons.wb_sunny_outlined,       'Светлая'),
    ('dark',   Icons.nightlight_round,         'Тёмная'),
    ('system', Icons.brightness_auto_outlined, 'Системная'),
  ];

  @override
  void initState() {
    super.initState();
    _lang     = html.window.localStorage['lang']  ?? 'ru';
    _themeKey = html.window.localStorage['theme'] ?? 'system';
  }

  void _setLang(String lang) {
    html.window.localStorage['lang'] = lang;
    AppState.langNotifier.value = lang;
    setState(() => _lang = lang);
  }

  void _setTheme(String key) {
    html.window.localStorage['theme'] = key;
    AppState.themeNotifier.value = AppState.parseTheme(key);
    setState(() => _themeKey = key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Настройки', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        flexibleSpace: const AppBarOrnament(),
      ),
      body: BodyOrnament(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Язык ──
          _label(context, 'Язык'),
          Container(
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: context.shadowC, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(children: _langs.map((t) {
              final (key, flag, label) = t;
              final selected = _lang == key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _setLang(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected ? kGradient : null,
                      color: selected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: selected ? null : Border.all(color: context.divC),
                    ),
                    child: Column(children: [
                      Text(flag, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : context.textC,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                ),
              );
            }).toList()),
          ),

          const SizedBox(height: 20),

          // ── Тема ──
          _label(context, 'Тема оформления'),
          Container(
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: context.shadowC, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(children: _themes.map((t) {
              final (key, icon, label) = t;
              final selected = _themeKey == key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _setTheme(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected ? kGradient : null,
                      color: selected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: selected ? null : Border.all(color: context.divC),
                    ),
                    child: Column(children: [
                      Icon(icon, size: 22, color: selected ? Colors.white : context.textC),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : context.textC,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                ),
              );
            }).toList()),
          ),

          const SizedBox(height: 20),

          // ── Уведомления ──
          _label(context, 'Уведомления'),
          _SectionCard(children: [
            _ToggleRow(
              icon: Icons.notifications_outlined,
              label: 'Push-уведомления',
              subtitle: 'Оповещения о новых водителях',
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
            Divider(height: 1, indent: 56, color: context.divC),
            _ToggleRow(
              icon: Icons.volume_up_outlined,
              label: 'Звук',
              subtitle: 'Звуковые сигналы при событиях',
              value: _soundEnabled,
              onChanged: (v) => setState(() => _soundEnabled = v),
            ),
          ]),
        ]),
      )),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: context.subC, letterSpacing: 0.4,
    )),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: context.iconBgC,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: context.iconC, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textC)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: context.subC)),
        ])),
        Switch(value: value, onChanged: onChanged, activeColor: kTeal),
      ]),
    );
  }
}


// ─── О ПРИЛОЖЕНИИ ────────────────────────────────────────────────────────────

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('О приложении', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        flexibleSpace: const AppBarOrnament(),
      ),
      body: BodyOrnament(child: SingleChildScrollView(
        child: Column(children: [

          // ── Логотип ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: kGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 14),
              const Text('ZHOLAUSHY', style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 4,
              )),
              const SizedBox(height: 6),
              Text('Версия 1.0.0', style: TextStyle(
                color: Colors.white.withOpacity(0.75), fontSize: 13,
              )),
              const SizedBox(height: 8),
              Text(
                'Межгородские поездки по Казахстану',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ]),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SectionCard(children: [
              _AboutRow(
                icon: Icons.location_on_outlined,
                label: 'Регион запуска',
                value: 'Актобе, Казахстан',
              ),
              Divider(height: 1, indent: 56, color: context.divC),
              _AboutRow(
                icon: Icons.verified_outlined,
                label: 'Разработчик',
                value: 'Zholaushy Team',
              ),
              Divider(height: 1, indent: 56, color: context.divC),
              _AboutRow(
                icon: Icons.email_outlined,
                label: 'Контакт',
                value: 'info@zholaushy.kz',
              ),
            ]),
          ),

          const SizedBox(height: 32),

          Text(
            '© 2026 Zholaushy. Все права защищены.',
            style: TextStyle(color: context.subC, fontSize: 12),
          ),
          const SizedBox(height: 24),
        ]),
      )),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: context.iconBgC,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: context.iconC, size: 20),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
            fontSize: 11, color: context.subC,
            fontWeight: FontWeight.w600, letterSpacing: 0.4,
          )),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textC)),
        ]),
      ]),
    );
  }
}

// ─── ОБЩИЙ КОМПОНЕНТ: СЕКЦИЯ-КАРТОЧКА ────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardC,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.shadowC,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
