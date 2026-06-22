import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String apiBase = 'http://localhost:8000/api/v1';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _routes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final dio = Dio();
      final res = await dio.get('$apiBase/routes/');
      final data = res.data;
      final list = data is Map ? (data['data'] ?? []) : data;
      if (mounted) {
        setState(() => _routes = List<Map<String, dynamic>>.from(list));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _getToken() => html.window.localStorage['token'];

  void _logout() {
    html.window.localStorage.remove('token');
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Жолаушы', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Мои поездки',
            onPressed: () => context.push('/history'),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car_outlined), text: 'Поездки'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Попутки'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TripsTab(getToken: _getToken, routes: _routes),
          _PoputkaTab(getToken: _getToken, routes: _routes),
        ],
      ),
    );
  }
}

// ─── ТАБ: ПОЕЗДКИ ───────────────────────────────────────────────────────────

class _TripsTab extends StatefulWidget {
  final String? Function() getToken;
  final List<Map<String, dynamic>> routes;
  const _TripsTab({required this.getToken, required this.routes});

  @override
  State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab> {
  List<dynamic> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final token = widget.getToken();
    if (token == null) return;
    try {
      final dio = Dio();
      final res = await dio.get(
        '$apiBase/trips/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      setState(() => _trips = data is List ? data : (data['data'] ?? []));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _routeName(int? routeId) {
    if (routeId == null) return '?';
    final r = widget.routes.where((r) => r['id'] == routeId).firstOrNull;
    if (r == null) return 'Маршрут #$routeId';
    return '${r['city_from']} → ${r['city_to']}';
  }

  void _showCreateRequest(BuildContext context) {
    Map<String, dynamic>? selectedRoute;
    final seatsController = TextEditingController(text: '1');
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Новая заявка', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: selectedRoute,
                decoration: InputDecoration(
                  labelText: 'Маршрут',
                  prefixIcon: const Icon(Icons.route_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: widget.routes.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text('${r['city_from']} → ${r['city_to']}'),
                )).toList(),
                onChanged: (v) => setModalState(() => selectedRoute = v),
                hint: const Text('Выберите маршрут'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seatsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Количество мест',
                  prefixIcon: Icon(Icons.event_seat_outlined),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) setModalState(() => selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate == null
                            ? 'Выберите дату'
                            : '${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year}',
                        style: TextStyle(color: selectedDate == null ? Colors.grey : Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: const TimeOfDay(hour: 8, minute: 0),
                  );
                  if (time != null) setModalState(() => selectedTime = time);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_outlined, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        selectedTime == null
                            ? 'Выберите время'
                            : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(color: selectedTime == null ? Colors.grey : Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedRoute == null || selectedDate == null || selectedTime == null) return;
                    final token = widget.getToken();
                    if (token == null) return;
                    final departure = DateTime(
                      selectedDate!.year, selectedDate!.month, selectedDate!.day,
                      selectedTime!.hour, selectedTime!.minute,
                    );
                    try {
                      await Dio().post(
                        '$apiBase/trip-requests/',
                        data: {
                          'route_id': selectedRoute!['id'],
                          'seats_needed': int.tryParse(seatsController.text) ?? 1,
                          'departure_date': departure.toIso8601String(),
                        },
                        options: Options(headers: {
                          'Authorization': 'Bearer $token',
                          'Content-Type': 'application/json',
                        }),
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Заявка создана! Ждите предложений от водителей.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Отправить заявку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showCreateRequest(context),
            icon: const Icon(Icons.add),
            label: const Text('Создать заявку'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _trips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 72, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Нет доступных поездок', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _trips.length,
                        itemBuilder: (_, i) => _TripCard(
                          trip: _trips[i],
                          routeName: _routeName(_trips[i]['route_id']),
                          getToken: widget.getToken,
                          onBooked: _fetch,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─── ТАБ: ПОПУТКИ ───────────────────────────────────────────────────────────

class _PoputkaTab extends StatefulWidget {
  final String? Function() getToken;
  final List<Map<String, dynamic>> routes;
  const _PoputkaTab({required this.getToken, required this.routes});

  @override
  State<_PoputkaTab> createState() => _PoputkaTabState();
}

class _PoputkaTabState extends State<_PoputkaTab> {
  Map<String, dynamic>? _selectedRoute;
  List<dynamic> _trips = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search() async {
    if (_selectedRoute == null) return;
    final token = widget.getToken();
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final dio = Dio();
      final res = await dio.get(
        '$apiBase/trips/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      final all = data is List ? data : (data['data'] ?? []);
      setState(() {
        _trips = all.where((t) => t['route_id'] == _selectedRoute!['id']).toList();
        _searched = true;
        _loading = false;
      });
    } catch (_) {
      setState(() { _loading = false; _searched = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Поиск попуток по маршруту
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedRoute,
                      decoration: InputDecoration(
                        labelText: 'Найти попутку по маршруту',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: widget.routes.map((r) => DropdownMenuItem(
                        value: r,
                        child: Text('${r['city_from']} → ${r['city_to']}'),
                      )).toList(),
                      onChanged: (v) => setState(() { _selectedRoute = v; _searched = false; _trips = []; }),
                      hint: const Text('Выберите маршрут'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _selectedRoute != null && !_loading ? _search : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(70, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Найти'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: !_searched
              ? _buildInitial()
              : _trips.isEmpty
                  ? _buildNoResults()
                  : RefreshIndicator(
                      onRefresh: _search,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _trips.length,
                        itemBuilder: (_, i) => _TripCard(
                          trip: _trips[i],
                          routeName: '${_selectedRoute!['city_from']} → ${_selectedRoute!['city_to']}',
                          getToken: widget.getToken,
                          onBooked: _search,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_alt_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Найдите попутку', style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Выберите маршрут выше и нажмите "Найти"', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Попуток по этому маршруту нет', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Ваша заявка уже создана — водители сами предложат цену',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── КАРТОЧКА ПОЕЗДКИ ───────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String routeName;
  final String? Function() getToken;
  final VoidCallback onBooked;
  const _TripCard({
    required this.trip,
    required this.routeName,
    required this.getToken,
    required this.onBooked,
  });

  void _showBookingDialog(BuildContext context) {
    int seats = 1;
    final price = (trip['price_per_seat'] ?? 0).toDouble();
    final available = trip['seats_available'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Бронирование'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(routeName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Мест: '),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: seats > 1 ? () => setState(() => seats--) : null,
                  ),
                  Text('$seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: seats < available ? () => setState(() => seats++) : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Итого: ${(price * seats).toStringAsFixed(0)} ₸',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final token = getToken();
                if (token == null) return;
                try {
                  final dio = Dio();
                  await dio.post(
                    '$apiBase/bookings/?trip_id=${trip['id']}&seats_count=$seats',
                    options: Options(headers: {'Authorization': 'Bearer $token'}),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Забронировано! ${(price * seats).toStringAsFixed(0)} ₸'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    onBooked();
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = trip['departure_time'] != null
        ? DateTime.tryParse(trip['departure_time'])
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.directions_car,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(routeName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      if (date != null)
                        Text(
                          '${date.day}.${date.month}.${date.year} в ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${trip['price_per_seat']} ₸',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_seat_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${trip['seats_available']} мест свободно',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _showBookingDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Забронировать'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
