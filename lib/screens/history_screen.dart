import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String _apiBase = 'http://localhost:8000/api/v1';

Widget _phoneButtons(String phone, Color primary) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => html.window.open('tel:$phone', '_self'),
      icon: const Icon(Icons.phone_outlined, size: 16),
      label: const Text('Позвонить', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
    ),
  );
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;

  String? get _token => html.window.localStorage['token'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final token = _token;
    if (token == null) { if (mounted) setState(() => _loading = false); return; }

    final dio = Dio();
    final headers = {'Authorization': 'Bearer $token'};
    final all = <Map<String, dynamic>>[];

    // Попутки (bookings) — завершённые
    try {
      final res = await dio.get('$_apiBase/bookings/my', options: Options(headers: headers));
      final list = res.data is List ? res.data as List : [];
      for (final b in list) {
        if (b['trip_status'] == 'completed') {
          all.add({
            'source':       'booking',
            'route_name':   b['route_name'],
            'departure_time': b['departure_time'],
            'driver_name':  b['driver_name'],
            'driver_phone': b['driver_phone'],
            'seats':        b['seats_count'],
            'price':        b['total_price'],
          });
        }
      }
    } catch (_) {}

    // Заявки InDriver — завершённые (status=accepted + trip_status=completed)
    try {
      final res = await dio.get('$_apiBase/trip-requests/my', options: Options(headers: headers));
      final list = res.data is List ? res.data as List : (res.data['data'] ?? []);
      for (final r in list) {
        if (r['status'] == 'accepted' && r['trip_status'] == 'completed') {
          all.add({
            'source':       'request',
            'route_name':   r['route_name'] ?? '—',
            'departure_time': r['departure_date'],
            'driver_name':  r['driver_name'],
            'driver_phone': r['driver_phone'],
            'seats':        r['seats_needed'],
            'price':        null,
          });
        }
      }
    } catch (_) {}

    // Сортируем по дате (новые первые)
    all.sort((a, b) {
      final da = a['departure_time'] != null ? DateTime.tryParse(a['departure_time']) : null;
      final db = b['departure_time'] != null ? DateTime.tryParse(b['departure_time']) : null;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    if (mounted) setState(() { _trips = all; _loading = false; });
  }

  void _showDriverInfo(BuildContext context, Map<String, dynamic> trip) {
    final name  = trip['driver_name']  as String? ?? '—';
    final phone = trip['driver_phone'] as String? ?? '—';
    final route = trip['route_name']   as String? ?? '—';
    final dt    = trip['departure_time'] != null
        ? DateTime.tryParse(trip['departure_time'])
        : null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text(route, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          if (dt != null) ...[
            const SizedBox(height: 4),
            Text(
              '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  '
              '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Данные водителя',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          _infoRow(Icons.person_outline, 'Имя', name),
          const SizedBox(height: 10),
          _infoRow(Icons.phone_outlined, 'Телефон', phone),
          const SizedBox(height: 16),
          _phoneButtons(phone, Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.grey[600]),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('История поездок', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.history, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Нет завершённых поездок', style: TextStyle(color: Colors.grey[500])),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (_, i) {
                      final t  = _trips[i];
                      final dt = t['departure_time'] != null
                          ? DateTime.tryParse(t['departure_time'])
                          : null;
                      final price = t['price'] as num?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showDriverInfo(context, t),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(
                                  t['route_name'] as String? ?? '—',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                )),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Завершено',
                                      style: TextStyle(color: Colors.blue[700], fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              if (dt != null)
                                _tripInfo(Icons.access_time_outlined,
                                  '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  '
                                  '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'),
                              const SizedBox(height: 4),
                              Row(children: [
                                if (t['seats'] != null) ...[
                                  _tripInfo(Icons.event_seat_outlined, '${t['seats']} мест'),
                                  const SizedBox(width: 16),
                                ],
                                if (price != null)
                                  _tripInfo(Icons.payments_outlined, '${price.toStringAsFixed(0)} ₸'),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Icon(Icons.person_outline, size: 14, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  t['driver_name'] as String? ?? '—',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                                const Spacer(),
                                Text('Нажмите для контакта',
                                    style: TextStyle(color: primary, fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, size: 16, color: primary),
                              ]),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _tripInfo(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: Colors.grey[400]),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
  ]);
}
