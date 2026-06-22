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

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _bookings = [];
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;

  String? get _token => html.window.localStorage['token'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    } on DioException catch (e) {
      if (mounted) setState(() => _error = 'Брони: ${e.response?.statusCode ?? e.message}');
    }
    try {
      final rRes = await dio.get('$_apiBase/trip-requests/my', options: Options(headers: headers));
      final r = rRes.data;
      if (mounted) setState(() => _requests = r is List ? r : (r['data'] ?? []));
    } on DioException catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('История', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.confirmation_num_outlined), text: 'Брони'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Заявки'),
          ],
        ),
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
              : TabBarView(
              controller: _tabController,
              children: [
                _buildBookings(),
                _buildRequests(),
              ],
            ),
    );
  }

  Widget _buildBookings() {
    if (_bookings.isEmpty) {
      return _empty(Icons.confirmation_num_outlined, 'Нет бронирований');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (_, i) => _BookingCard(booking: _bookings[i], onCancel: _load),
      ),
    );
  }

  Widget _buildRequests() {
    if (_requests.isEmpty) {
      return _empty(Icons.people_alt_outlined, 'Нет заявок');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (_, i) => _RequestHistoryCard(request: _requests[i]),
      ),
    );
  }

  Widget _empty(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onCancel;
  const _BookingCard({required this.booking, required this.onCancel});

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'confirmed': return 'Подтверждено';
      case 'cancelled': return 'Отменено';
      default: return status;
    }
  }

  void _cancel(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить бронь?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final token = html.window.localStorage['token'];
    if (token == null) return;
    try {
      await Dio().delete(
        '$_apiBase/bookings/${booking['id']}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      onCancel();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] ?? 'pending';
    final isCancelled = status == 'cancelled';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_num_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Бронь #${booking['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusText(status),
                      style: TextStyle(color: _statusColor(status), fontSize: 12)),
                ),
              ],
            ),
            if (booking['route_name'] != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.route_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(booking['route_name'], style: const TextStyle(fontWeight: FontWeight.w500)),
              ]),
            ],
            if (booking['departure_time'] != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.schedule_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Builder(builder: (_) {
                  final dt = DateTime.tryParse(booking['departure_time']);
                  if (dt == null) return const SizedBox();
                  return Text(
                    '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                    style: TextStyle(color: Colors.grey[600]),
                  );
                }),
              ]),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_seat_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${booking['seats_count']} мест',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(width: 16),
                Icon(Icons.payments_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${(booking['total_price'] as num).toStringAsFixed(0)} ₸',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            if (!isCancelled) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _cancel(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Отменить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  final Map<String, dynamic> request;
  const _RequestHistoryCard({required this.request});

  Color _statusColor(String status) {
    switch (status) {
      case 'open': return Colors.blue;
      case 'accepted': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'open': return 'Открыта';
      case 'accepted': return 'Принята';
      case 'cancelled': return 'Отменена';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = request['status'] ?? 'open';
    final date = request['departure_date'] != null
        ? DateTime.tryParse(request['departure_date'])
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_alt_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Заявка #${request['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusText(status),
                      style: TextStyle(color: _statusColor(status), fontSize: 12)),
                ),
              ],
            ),
            if (request['route_name'] != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.route_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(request['route_name'], style: const TextStyle(fontWeight: FontWeight.w500)),
              ]),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_seat_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${request['seats_needed']} мест',
                    style: TextStyle(color: Colors.grey[600])),
                if (date != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
