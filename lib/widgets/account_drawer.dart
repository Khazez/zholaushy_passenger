import 'package:flutter/material.dart';
import '../theme.dart';
import 'avatar_picker.dart';

/// Боковая шторка меню профиля (Scaffold.endDrawer) — общая для
/// пассажирского и водительского режимов. Шапка (аватар+имя+роль)
/// кликабельна целиком и ведёт в профиль.
class AccountDrawer extends StatelessWidget {
  final String name;
  final String role;
  final VoidCallback onProfile;
  final VoidCallback onSupport;
  final VoidCallback onSettings;
  final VoidCallback onAbout;
  final VoidCallback onLogout;

  const AccountDrawer({
    super.key,
    required this.name,
    required this.role,
    required this.onProfile,
    required this.onSupport,
    required this.onSettings,
    required this.onAbout,
    required this.onLogout,
  });

  String get _initials => name.trim().split(' ')
      .where((p) => p.isNotEmpty).take(2)
      .map((p) => p[0].toUpperCase()).join();

  void _tap(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  Widget _tile(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    final labelColor = danger ? Colors.red[600]! : context.textC;
    final iconColor  = danger ? Colors.red[600]! : context.subC;
    return InkWell(
      onTap: () => _tap(context, onTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: labelColor)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.cardC,
      width: MediaQuery.of(context).size.width * 0.83,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 18),
          children: [
            InkWell(
              onTap: () => _tap(context, onProfile),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
                child: Row(children: [
                  AvatarView(avatarUrl: null, initials: _initials.isEmpty ? '?' : _initials, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: context.textC),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 18, color: context.textC.withValues(alpha: 0.35)),
                      ]),
                      const SizedBox(height: 2),
                      Text(role, style: TextStyle(fontSize: 11.5, color: context.subC)),
                    ]),
                  ),
                ]),
              ),
            ),
            Divider(height: 1, color: context.divC, indent: 18, endIndent: 18),
            _tile(context, Icons.headset_mic_outlined, 'Служба поддержки', onSupport),
            _tile(context, Icons.settings_outlined, 'Настройки', onSettings),
            _tile(context, Icons.info_outline, 'О приложении', onAbout),
            Divider(height: 1, color: context.divC, indent: 18, endIndent: 18),
            _tile(context, Icons.logout, 'Выйти', onLogout, danger: true),
          ],
        ),
      ),
    );
  }
}
