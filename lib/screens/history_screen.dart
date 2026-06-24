import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String _apiBase = 'http://localhost:8000/api/v1';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _bookings = [];
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;

  String? get _token => html.window.localStorage['token'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    final token = _token;
    if (token == null) {
      setState(() { _loading = false; _error = 'Не авторизован'; });
      return;
    }
    final dio = Dio();
    final headers = {'Authorization': 'Bearer $token'};
    try {
      final bRes = await dio.get('$_apiBase/bookings/my', options: Options(headers: headers));
      final b = bRes.data;
      if (mounted) setState(() => _bookings = b is List ? b : (b['data'] ?? []));
    } on DioException catch (_) {}
    try {
      final rRes = await dio.get('$_apiBase/trip-requests/my', options: Options(headers: headers));
      final r = rRes.data;
      if (mounted) setState(() => _requests = r is List ? r : (r['data'] ?? []));
    } on DioException catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final doneBookings = _bookings.where((b) {
      final s = b['status'] ?? '';
      return s == 'completed' || s == 'confirmed' || s == 'cancelled';
    }).toList();

    final doneRequests = _requests.where((r) {
      final s = r['status'] ?? '';
      return s == 'accepted' || s == 'cancelled';
    }).toList();

    final isEmpty = doneBookings.isEmpty && doneRequests.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('История поездок', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Повторить')),
                ]))
              : isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.history, size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('Нет завершённых поездок', style: TextStyle(color: Colors.grey[500])),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final b in doneBookings)
                            _BookingCard(booking: b, token: _token),
                          for (final r in doneRequests)
                            _RequestCard(request: r),
                        ],
                      ),
                    ),
    );
  }
}

// ─── КАРТОЧКА БРОНИ ──────────────────────────────────────────────────────────

class _BookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String? token;
  const _BookingCard({required this.booking, required this.token});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _rated = false;

  Color _statusColor(String s) => switch (s) {
    'confirmed' => Colors.green,
    'completed' => Colors.blue,
    'cancelled' => Colors.red,
    _ => Colors.orange,
  };

  String _statusText(String s) => switch (s) {
    'confirmed' => 'Подтверждено',
    'completed' => 'Завершено',
    'cancelled' => 'Отменено',
    _ => s,
  };

  Future<void> _openRating() async {
    final tripId   = widget.booking['trip_id']   as int?;
    final driverId = widget.booking['driver_id'] as int?;
    if (tripId == null || driverId == null) return;

    int selectedStars = 5;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Оценить водителя', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Как прошла поездка?',
                style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setSt(() => selectedStars = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
              );
            })),
            const SizedBox(height: 12),
            Text(
              ['', 'Ужасно', 'Плохо', 'Нормально', 'Хорошо', 'Отлично!'][selectedStars],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await Dio().post(
        '$_apiBase/ratings/',
        data: {'trip_id': tripId, 'to_user_id': driverId, 'score': selectedStars},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
        ),
      );
      setState(() => _rated = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Спасибо за оценку!'), backgroundColor: Colors.green),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
        if (msg.contains('уже оценили')) setState(() => _rated = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b      = widget.booking;
    final status = b['status'] ?? '';
    final tripStatus = b['trip_status'] ?? '';
    final dt     = b['departure_time'] != null ? DateTime.tryParse(b['departure_time']) : null;
    final canRate = tripStatus == 'completed' && !_rated;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(b['route_name'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(width: 8),
            _Badge(label: _statusText(status), color: _statusColor(status)),
          ]),
          if (dt != null) ...[
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.schedule_outlined,
                text: '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  '
                    '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'),
          ],
          const SizedBox(height: 4),
          Row(children: [
            _InfoRow(icon: Icons.event_seat_outlined, text: '${b['seats_count']} мест'),
            const SizedBox(width: 16),
            _InfoRow(icon: Icons.payments_outlined,
                text: '${(b['total_price'] as num).toStringAsFixed(0)} ₸'),
          ]),
          if (canRate) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openRating,
                icon: const Icon(Icons.star_outline_rounded, size: 18),
                label: const Text('Оценить водителя'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber[700],
                  side: BorderSide(color: Colors.amber[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ],
          if (_rated)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.green[600]),
                const SizedBox(width: 6),
                Text('Вы оценили эту поездку',
                    style: TextStyle(color: Colors.green[700], fontSize: 13)),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ─── КАРТОЧКА ЗАЯВКИ ─────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = request['status'] ?? '';
    final isAccepted = status == 'accepted';
    final date = request['departure_date'] != null ? DateTime.tryParse(request['departure_date']) : null;
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAccepted ? primary.withOpacity(0.35) : Colors.grey[200]!,
          width: isAccepted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Маршрут + статус
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(request['route_name'] ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 8),
            _Badge(
              label: isAccepted ? 'Выполнена' : 'Отменена',
              color: isAccepted ? primary : Colors.red,
            ),
          ]),

          if (date != null) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.schedule_outlined,
              text: '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}  '
                  '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}',
            ),
          ],
          const SizedBox(height: 4),
          _InfoRow(icon: Icons.event_seat_outlined, text: '${request['seats_needed']} мест'),

          // Блок водителя
          if (isAccepted && (request['driver_name'] != null || request['driver_phone'] != null)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withOpacity(0.15)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.directions_car_outlined, size: 13, color: primary),
                  const SizedBox(width: 5),
                  Text('ВОДИТЕЛЬ',
                      style: TextStyle(color: primary, fontSize: 11,
                          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 8),
                if (request['driver_name'] != null)
                  Row(children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(request['driver_name'],
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ]),
                if (request['driver_phone'] != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.phone_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(request['driver_phone'],
                        style: TextStyle(fontSize: 15, color: primary, fontWeight: FontWeight.w500)),
                  ]),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ─────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    ]);
  }
}
