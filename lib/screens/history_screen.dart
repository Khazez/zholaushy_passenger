import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../local_store.dart';
import '../url_helper.dart';
import '../config.dart';
import '../theme.dart';

Widget _phoneButtons(String phone) {
  return SizedBox(
    width: double.infinity,
    child: GestureDetector(
      onTap: () => openUrl('tel:$phone'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: kTeal.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.phone_outlined, size: 16, color: kTeal),
          SizedBox(width: 6),
          Text('Позвонить', style: TextStyle(fontSize: 13, color: kTeal, fontWeight: FontWeight.w600)),
        ]),
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

  String? get _token => LocalStore.getString('token');

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
      final res = await dio.get('$kApiBase/bookings/my', options: Options(headers: headers));
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

    // Заявки InDriver — завершённые
    try {
      final res = await dio.get('$kApiBase/trip-requests/my', options: Options(headers: headers));
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

  void _showTripDetails(BuildContext context, Map<String, dynamic> trip) {
    final name  = trip['driver_name']  as String? ?? '—';
    final phone = trip['driver_phone'] as String? ?? '—';
    final route = trip['route_name']   as String? ?? '—';
    final seats = trip['seats'];
    final price = trip['price'] as num?;
    final dt    = trip['departure_time'] != null
        ? DateTime.tryParse(trip['departure_time'])
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardC,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Ручка
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: context.divC, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Заголовок + бейдж
          Row(children: [
            Expanded(child: Text(route,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: context.textC))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Завершено',
                  style: TextStyle(color: kTeal, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),

          if (dt != null) ...[
            const SizedBox(height: 6),
            Text(
              '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  '
              '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
              style: TextStyle(color: context.subC, fontSize: 14),
            ),
          ],

          const SizedBox(height: 20),
          Divider(height: 1, color: context.divC),
          const SizedBox(height: 20),

          // Детали поездки
          Text('Детали поездки',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.subC)),
          const SizedBox(height: 12),
          if (seats != null) ...[
            _infoRow(context, Icons.event_seat_outlined, 'Мест', '$seats'),
            const SizedBox(height: 10),
          ],
          if (price != null) ...[
            _infoRow(context, Icons.payments_outlined, 'Стоимость', '${price.toStringAsFixed(0)} ₸'),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 4),
          Divider(height: 1, color: context.divC),
          const SizedBox(height: 16),

          // Данные водителя
          Text('Водитель',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.subC)),
          const SizedBox(height: 12),
          _infoRow(context, Icons.person_outline, 'Имя', name),
          const SizedBox(height: 10),
          _infoRow(context, Icons.phone_outlined, 'Телефон', phone),
          const SizedBox(height: 16),
          if (phone != '—') _phoneButtons(phone),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: context.iconBgC,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: context.iconC),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.subC)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textC)),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('История поездок', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        flexibleSpace: const AppBarOrnament(),
      ),
      body: BodyOrnament(child: _loading
          ? const Center(child: CircularProgressIndicator(color: kNavy))
          : _trips.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.history, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Нет завершённых поездок', style: TextStyle(color: Colors.grey[500])),
                ]))
              : RefreshIndicator(
                  color: kNavy,
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: context.cardC,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.divC),
                          boxShadow: [BoxShadow(color: kNavy.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showTripDetails(context, t),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(
                                  t['route_name'] as String? ?? '—',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.textC),
                                )),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kTeal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Завершено',
                                      style: TextStyle(color: kTeal, fontSize: 12,
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
                                const Text('Нажмите для контакта',
                                    style: TextStyle(color: kTeal, fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 16, color: kTeal),
                              ]),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    ));
  }

  Widget _tripInfo(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: Colors.grey[400]),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
  ]);
}
