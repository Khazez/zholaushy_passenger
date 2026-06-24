import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'profile_screen.dart';
import 'info_screens.dart';

const String apiBase = 'http://localhost:8000/api/v1';

// Пара полей: адрес + подъезд
class _AddrPair {
  final TextEditingController address;
  final TextEditingController entrance;
  _AddrPair({String addr = '', String entr = ''})
      : address = TextEditingController(text: addr),
        entrance = TextEditingController(text: entr);
  void dispose() { address.dispose(); entrance.dispose(); }
  bool get hasAddress => address.text.trim().isNotEmpty;
  Map<String, dynamic> toMap() {
    final a = address.text.trim();
    final e = entrance.text.trim();
    return {'address': a, if (e.isNotEmpty) 'entrance': e};
  }
}

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
      final res = await Dio().get('$apiBase/routes/');
      final data = res.data;
      final list = data is Map ? (data['data'] ?? []) : data;
      if (mounted) setState(() => _routes = List<Map<String, dynamic>>.from(list));
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

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {bool danger = false}) {
    final color = danger ? Colors.red[600]! : Colors.black87;
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: color)),
      ]),
    );
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
            icon: const Icon(Icons.history),
            tooltip: 'История поездок',
            onPressed: () => context.push('/history'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            offset: const Offset(0, 48),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ));
                  break;
                case 'support':
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SupportScreen(),
                  ));
                  break;
                case 'settings':
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ));
                  break;
                case 'about':
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AboutScreen(),
                  ));
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (_) => [
              _menuItem('profile', Icons.person_outline, 'Профиль'),
              _menuItem('support', Icons.headset_mic_outlined, 'Служба поддержки'),
              _menuItem('settings', Icons.settings_outlined, 'Настройки'),
              _menuItem('about', Icons.info_outline, 'О приложении'),
              const PopupMenuDivider(),
              _menuItem('logout', Icons.logout, 'Выйти', danger: true),
            ],
          ),
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

// ─── ТАБ: ПОЕЗДКИ (личный дашборд пассажира) ────────────────────────────────

class _TripsTab extends StatefulWidget {
  final String? Function() getToken;
  final List<Map<String, dynamic>> routes;
  const _TripsTab({required this.getToken, required this.routes});

  @override
  State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab> {
  List<dynamic> _requests = [];
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final token = widget.getToken();
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final dio = Dio();
    final headers = {'Authorization': 'Bearer $token'};

    try {
      final res = await dio.get(
        '$apiBase/trip-requests/my',
        options: Options(headers: headers),
      ).timeout(const Duration(seconds: 6));
      final data = res.data;
      final all = data is List ? data : (data['data'] ?? []);
      _requests = all.where((r) => r['status'] == 'open' || r['status'] == 'accepted').toList();
    } catch (_) {}

    try {
      final res = await dio.get(
        '$apiBase/bookings/my',
        options: Options(headers: headers),
      ).timeout(const Duration(seconds: 6));
      final data = res.data;
      final all = data is List ? data : (data['data'] ?? []);
      _bookings = all.where((b) => b['status'] != 'cancelled' && b['status'] != 'completed').toList();
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  String _routeName(int? routeId) {
    if (routeId == null) return '?';
    final r = widget.routes.where((r) => r['id'] == routeId).firstOrNull;
    if (r == null) return 'Маршрут #$routeId';
    return '${r['city_from']} → ${r['city_to']}';
  }

  void _showCreateRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CreateRequestScreen(
          routes: widget.routes,
          getToken: widget.getToken,
          onCreated: () {
            _load();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Заявка создана! Ждите предложений от водителей.'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acceptedRequests = _requests.where((r) => r['status'] == 'accepted').toList();
    final pendingRequests = _requests.where((r) => r['status'] == 'open').toList();
    final hasContent = _bookings.isNotEmpty || _requests.isNotEmpty;

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
              : !hasContent
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 72, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Нет активных поездок', style: TextStyle(color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Text('Создайте заявку — водители предложат цену',
                              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Принятые заявки — большая карточка
                          for (final r in acceptedRequests)
                            _AcceptedRequestCard(
                              request: r,
                              routeName: r['route_name'] ?? _routeName(r['route_id']),
                              onRefresh: _load,
                            ),

                          // Активные брони
                          for (final b in _bookings)
                            _ActiveBookingCard(booking: b, onRefresh: _load),

                          // Ожидающие заявки — маленькие
                          if (pendingRequests.isNotEmpty) ...[
                            if (acceptedRequests.isNotEmpty || _bookings.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 4),
                                child: Text('Ожидают водителя',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            for (final r in pendingRequests)
                              _PendingRequestCard(
                                request: r,
                                routeName: r['route_name'] ?? _routeName(r['route_id']),
                                onRefresh: _load,
                              ),
                          ],
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

// Большая карточка — заявку взял водитель
class _AcceptedRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String routeName;
  final VoidCallback onRefresh;
  const _AcceptedRequestCard({required this.request, required this.routeName, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final date = request['departure_date'] != null ? DateTime.tryParse(request['departure_date']) : null;
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20)),
                child: const Text('Водитель найден!', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(routeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            if (date != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}  '
                  '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ]),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.event_seat_outlined, size: 15, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text('${request['seats_needed']} мест', style: TextStyle(color: Colors.grey[600])),
            ]),
            if (request['driver_name'] != null || request['driver_phone'] != null) ...[
              const Divider(height: 20),
              if (request['driver_name'] != null)
                Row(children: [
                  Icon(Icons.person_outline, size: 16, color: primary),
                  const SizedBox(width: 6),
                  Text(request['driver_name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                ]),
              if (request['driver_phone'] != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.phone_outlined, size: 16, color: primary),
                  const SizedBox(width: 6),
                  Text(request['driver_phone'], style: TextStyle(color: primary, fontWeight: FontWeight.w500)),
                ]),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// Карточка активной брони
class _ActiveBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onRefresh;
  const _ActiveBookingCard({required this.booking, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final date = booking['departure_time'] != null ? DateTime.tryParse(booking['departure_time']) : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.confirmation_num_outlined, color: Colors.green.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(booking['route_name'] ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (date != null)
                  Text(
                    '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(booking['total_price'] as num?)?.toStringAsFixed(0) ?? '—'} ₸',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              Text('${booking['seats_count'] ?? 1} мест',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}

// Карточка ожидающей заявки — тап открывает экран офферов
class _PendingRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String routeName;
  final VoidCallback? onRefresh;
  const _PendingRequestCard({required this.request, required this.routeName, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final date = request['departure_date'] != null ? DateTime.tryParse(request['departure_date']) : null;
    final payment = request['payment_type'] ?? 'cash';
    final paymentLabel = payment == 'card' ? 'Карта' : payment == 'kaspi' ? 'Kaspi' : 'Наличные';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _OffersScreen(
            request: request,
            routeName: routeName,
            onDone: onRefresh,
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.orange.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.schedule, size: 16, color: Colors.orange[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(routeName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                  child: Text('Ожидает', style: TextStyle(color: Colors.orange[700], fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 6),
              if (date != null)
                Text(
                  '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}  '
                  '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              const SizedBox(height: 4),
              Wrap(spacing: 12, children: [
                _chip(Icons.event_seat_outlined, '${request['seats_needed'] ?? 1} мест'),
                _chip(Icons.payments_outlined, paymentLabel),
                if (request['pickup_address'] != null)
                  _chip(Icons.location_on_outlined, request['pickup_address']),
              ]),
              const SizedBox(height: 6),
              Text('Нажмите, чтобы увидеть предложения',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: Colors.grey[500]),
    const SizedBox(width: 3),
    Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
  ]);
}

// ─── ЭКРАН ПРЕДЛОЖЕНИЙ ВОДИТЕЛЕЙ ─────────────────────────────────────────────

class _OffersScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  final String routeName;
  final VoidCallback? onDone;

  const _OffersScreen({
    required this.request,
    required this.routeName,
    this.onDone,
  });

  @override
  State<_OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<_OffersScreen> {
  List<dynamic> _offers = [];
  bool _loading = true;
  int? _accepting;

  String? _getToken() => html.window.localStorage['token'];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _loading = true);
    final token = _getToken();
    if (token == null) return;
    try {
      final res = await Dio().get(
        '$apiBase/trip-requests/${widget.request['id']}/offers',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 8));
      setState(() {
        _offers = res.data is List ? res.data : [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(int offerId) async {
    // Показываем подтверждение адреса перед принятием
    final addressCtrl = TextEditingController(
        text: widget.request['pickup_address'] as String? ?? '');
    final entranceCtrl = TextEditingController(
        text: widget.request['entrance'] as String? ?? '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Адрес подачи',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 4),
          Text('Водитель увидит этот адрес',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: addressCtrl,
            autofocus: (widget.request['pickup_address'] as String?)?.isEmpty ?? true,
            decoration: InputDecoration(
              labelText: 'Улица, дом',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: entranceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Подъезд (необязательно)',
              prefixIcon: const Icon(Icons.door_front_door_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Отмена'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Подтвердить', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ]),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Обновляем адрес в заявке если изменился
    final token = _getToken();
    final newAddress  = addressCtrl.text.trim();
    final newEntrance = entranceCtrl.text.trim();
    final oldAddress  = widget.request['pickup_address'] as String? ?? '';
    final oldEntrance = widget.request['entrance'] as String? ?? '';
    if (newAddress != oldAddress || newEntrance != oldEntrance) {
      try {
        await Dio().patch(
          '$apiBase/trip-requests/${widget.request['id']}',
          data: {
            'pickup_address': newAddress.isEmpty ? null : newAddress,
            'entrance': newEntrance.isEmpty ? null : newEntrance,
          },
          options: Options(headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          }),
        );
      } catch (_) {}
    }

    setState(() => _accepting = offerId);
    try {
      await Dio().post(
        '$apiBase/trip-requests/${widget.request['id']}/accept/$offerId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 8));
      widget.onDone?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Водитель принят! Поездка подтверждена.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $msg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditRequestScreen(
          request: widget.request,
          routeName: widget.routeName,
          onSaved: () {
            widget.onDone?.call();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final date = widget.request['departure_date'] != null
        ? DateTime.tryParse(widget.request['departure_date'])
        : null;
    final payment = widget.request['payment_type'] ?? 'cash';
    final paymentLabel = payment == 'card' ? 'Карта' : payment == 'kaspi' ? 'Kaspi' : 'Наличные';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Предложения водителей', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Редактировать заявку',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOffers,
          ),
        ],
      ),
      body: Column(children: [

        // ── Шапка с деталями заявки ──
        Container(
          color: primary.withValues(alpha: 0.05),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.routeName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 6, children: [
              if (date != null)
                _tag(Icons.calendar_today_outlined,
                    '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}  '
                    '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}'),
              _tag(Icons.event_seat_outlined, '${widget.request['seats_needed'] ?? 1} мест'),
              _tag(Icons.payments_outlined, paymentLabel),
              if (widget.request['pickup_address'] != null)
                _tag(Icons.location_on_outlined, widget.request['pickup_address']),
            ]),
          ]),
        ),

        const Divider(height: 1),

        // ── Список офферов ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _offers.isEmpty
                  ? _emptyState(primary)
                  : RefreshIndicator(
                      onRefresh: _loadOffers,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _offers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _OfferCard(
                          offer: _offers[i],
                          seatsNeeded: widget.request['seats_needed'] ?? 1,
                          isAccepting: _accepting == _offers[i]['id'],
                          onAccept: () => _accept(_offers[i]['id']),
                          primary: primary,
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _tag(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: Colors.grey[600]),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
  ]);

  Widget _emptyState(Color primary) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.hourglass_empty_rounded, size: 72, color: Colors.grey[300]),
      const SizedBox(height: 16),
      const Text('Ждём водителей',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Водители видят вашу заявку и скоро откликнутся',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      TextButton.icon(
        onPressed: _loadOffers,
        icon: const Icon(Icons.refresh),
        label: const Text('Обновить'),
      ),
    ]),
  );
}

// Карточка одного предложения от водителя
class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final int seatsNeeded;
  final bool isAccepting;
  final VoidCallback onAccept;
  final Color primary;

  const _OfferCard({
    required this.offer,
    required this.seatsNeeded,
    required this.isAccepting,
    required this.onAccept,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final depTime = offer['departure_time'] != null
        ? DateTime.tryParse(offer['departure_time'])
        : null;
    final pricePerSeat = (offer['price_per_seat'] as num?)?.toStringAsFixed(0) ?? '—';
    final totalPrice   = (offer['total_price']   as num?)?.toStringAsFixed(0) ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Водитель
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(
              child: Text(
                (offer['driver_name'] as String? ?? '?')[0].toUpperCase(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(offer['driver_name'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(offer['driver_phone'] ?? '—',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ])),
          // Цена за всё
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$totalPrice ₸',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
            if (seatsNeeded > 1)
              Text('$pricePerSeat ₸/место',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ]),
        ]),

        if (depTime != null) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.access_time_outlined, size: 15, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              'Отправление: ${depTime.day.toString().padLeft(2,'0')}.${depTime.month.toString().padLeft(2,'0')}  '
              '${depTime.hour.toString().padLeft(2,'0')}:${depTime.minute.toString().padLeft(2,'0')}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const Spacer(),
            Icon(Icons.event_seat_outlined, size: 15, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text('${offer['seats_available'] ?? '?'} св.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ]),
        ],

        const SizedBox(height: 14),

        // Кнопка принять
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isAccepting ? null : onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: Size.zero,
            ),
            child: isAccepting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Принять водителя', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ─── ФОРМА БРОНИРОВАНИЯ ПОЕЗДКИ ──────────────────────────────────────────────

class _BookingFormScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final String routeName;
  final String? Function() getToken;
  final VoidCallback onBooked;

  const _BookingFormScreen({
    required this.trip,
    required this.routeName,
    required this.getToken,
    required this.onBooked,
  });

  @override
  State<_BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<_BookingFormScreen> {
  int _seats = 1;
  final _addressCtrl              = TextEditingController();
  final _entranceCtrl             = TextEditingController();
  final _destinationCtrl          = TextEditingController();
  final _destinationEntranceCtrl  = TextEditingController();
  final _nameCtrl                 = TextEditingController();
  final _phoneCtrl                = TextEditingController();
  final _commentCtrl              = TextEditingController();
  final List<_AddrPair> _extraPairs    = [];
  final List<_AddrPair> _extraDestPairs = [];
  bool _forOther = false;
  bool _saving   = false;

  @override
  void dispose() {
    _addressCtrl.dispose(); _entranceCtrl.dispose();
    _destinationCtrl.dispose(); _destinationEntranceCtrl.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _commentCtrl.dispose();
    for (final p in _extraPairs) p.dispose();
    for (final p in _extraDestPairs) p.dispose();
    super.dispose();
  }

  void _addExtraPickup()  => setState(() => _extraPairs.add(_AddrPair()));
  void _removeExtraPickup(int i) => setState(() { _extraPairs[i].dispose(); _extraPairs.removeAt(i); });
  void _addExtraDest()    => setState(() => _extraDestPairs.add(_AddrPair()));
  void _removeExtraDest(int i) => setState(() { _extraDestPairs[i].dispose(); _extraDestPairs.removeAt(i); });

  Future<void> _submit() async {
    final token = widget.getToken();
    if (token == null) return;
    setState(() => _saving = true);

    final price     = (widget.trip['price_per_seat'] as num?)?.toDouble() ?? 0;
    final available = widget.trip['seats_available'] as int? ?? 0;
    if (_seats > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостаточно мест')));
      setState(() => _saving = false);
      return;
    }

    final extraPickups = _extraPairs.where((p) => p.hasAddress).map((p) => p.toMap()).toList();
    final extraDests   = _extraDestPairs.where((p) => p.hasAddress).map((p) => p.toMap()).toList();

    try {
      await Dio().post(
        '$apiBase/bookings/',
        data: {
          'trip_id': widget.trip['id'],
          'seats_count': _seats,
          if (_addressCtrl.text.isNotEmpty)             'pickup_address': _addressCtrl.text.trim(),
          if (_entranceCtrl.text.isNotEmpty)            'entrance': _entranceCtrl.text.trim(),
          if (extraPickups.isNotEmpty)                  'extra_pickups': extraPickups,
          if (_destinationCtrl.text.isNotEmpty)         'destination_address': _destinationCtrl.text.trim(),
          if (_destinationEntranceCtrl.text.isNotEmpty) 'destination_entrance': _destinationEntranceCtrl.text.trim(),
          if (extraDests.isNotEmpty)                    'extra_destinations': extraDests,
          if (_forOther && _nameCtrl.text.isNotEmpty)   'contact_name': _nameCtrl.text.trim(),
          if (_forOther && _phoneCtrl.text.isNotEmpty)  'contact_phone': _phoneCtrl.text.trim(),
          if (_commentCtrl.text.isNotEmpty)             'comment': _commentCtrl.text.trim(),
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );
      widget.onBooked();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Забронировано! ${(price * _seats).toStringAsFixed(0)} ₸'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary   = Theme.of(context).colorScheme.primary;
    final price     = (widget.trip['price_per_seat'] as num?)?.toDouble() ?? 0;
    final available = widget.trip['seats_available'] as int? ?? 0;
    final dep       = widget.trip['departure_time'] != null
        ? DateTime.tryParse(widget.trip['departure_time']) : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Бронирование', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Сводка поездки
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withValues(alpha: 0.15)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.routeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (dep != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${dep.day.toString().padLeft(2,'0')}.${dep.month.toString().padLeft(2,'0')}.${dep.year}  '
                  '${dep.hour.toString().padLeft(2,'0')}:${dep.minute.toString().padLeft(2,'0')}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 6),
              Text('${price.toStringAsFixed(0)} ₸ за место',
                  style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
            ]),
          ),

          const SizedBox(height: 20),
          _sectionTitle('Количество мест'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              IconButton(
                onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: primary,
              ),
              Expanded(child: Column(children: [
                Text('$_seats', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('${(price * _seats).toStringAsFixed(0)} ₸ итого',
                    style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
              ])),
              IconButton(
                onPressed: _seats < available ? () => setState(() => _seats++) : null,
                icon: const Icon(Icons.add_circle_outline),
                color: primary,
              ),
            ]),
          ),

          const SizedBox(height: 20),
          _sectionTitle('Откуда забрать (адрес А)'),
          _field(_addressCtrl, 'Улица, дом', Icons.location_on_outlined),
          const SizedBox(height: 10),
          _field(_entranceCtrl, 'Подъезд (необязательно)', Icons.door_front_door_outlined),

          // Доп. адреса подачи
          for (int i = 0; i < _extraPairs.length; i++) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_extraPairs[i].address,
                  'Адрес ${i + 2} (доп. пассажир)', Icons.add_location_alt_outlined)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeExtraPickup(i),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 6),
            _field(_extraPairs[i].entrance, 'Подъезд (необязательно)', Icons.door_front_door_outlined),
          ],

          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _addExtraPickup,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Добавить адрес подачи'),
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 20),
          _sectionTitle('Куда довезти (адрес Б)'),
          _field(_destinationCtrl, 'Улица, дом назначения', Icons.flag_outlined),
          const SizedBox(height: 10),
          _field(_destinationEntranceCtrl, 'Подъезд назначения (необязательно)', Icons.door_front_door_outlined),
          for (int i = 0; i < _extraDestPairs.length; i++) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_extraDestPairs[i].address,
                  'Адрес Б${i + 2} (доп. точка)', Icons.flag_circle_outlined)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeExtraDest(i),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 6),
            _field(_extraDestPairs[i].entrance, 'Подъезд (необязательно)', Icons.door_front_door_outlined),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addExtraDest,
            icon: const Icon(Icons.flag_circle_outlined),
            label: const Text('Добавить точку назначения'),
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 20),
          Row(children: [
            _sectionTitle('Заказ для другого человека'),
            const Spacer(),
            Switch(value: _forOther, onChanged: (v) => setState(() => _forOther = v), activeColor: primary),
          ]),
          if (_forOther) ...[
            const SizedBox(height: 8),
            _field(_nameCtrl,  'Имя пассажира', Icons.person_outline),
            const SizedBox(height: 12),
            _field(_phoneCtrl, 'Номер телефона', Icons.phone_outlined, type: TextInputType.phone),
          ],

          const SizedBox(height: 20),
          _sectionTitle('Комментарий водителю'),
          _field(_commentCtrl, 'Необязательно...', Icons.comment_outlined, maxLines: 3),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Забронировать · ${(price * _seats).toStringAsFixed(0)} ₸',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
  );

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType type = TextInputType.text, int maxLines = 1}) =>
    TextField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
}

// ─── КОМПАКТНЫЙ ПИКЕР ДАТЫ И ВРЕМЕНИ ────────────────────────────────────────

class _DateTimePicker extends StatefulWidget {
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<TimeOfDay> onTimeSelected;

  const _DateTimePicker({
    this.selectedDate,
    this.selectedTime,
    required this.onDateSelected,
    required this.onTimeSelected,
  });

  @override
  State<_DateTimePicker> createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<_DateTimePicker> {
  static const _monthNames = [
    'Янв','Фев','Мар','Апр','Май','Июн',
    'Июл','Авг','Сен','Окт','Ноя','Дек',
  ];

  late int _day, _month, _year, _hour, _minute;

  late TextEditingController _dayCtrl, _monthCtrl, _yearCtrl, _hourCtrl, _minCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.selectedDate ?? DateTime.now().add(const Duration(days: 1));
    final t = widget.selectedTime ?? const TimeOfDay(hour: 8, minute: 0);
    _day = d.day; _month = d.month; _year = d.year;
    _hour = t.hour; _minute = t.minute;
    _dayCtrl   = TextEditingController(text: _day.toString().padLeft(2,'0'));
    _monthCtrl = TextEditingController(text: _month.toString().padLeft(2,'0'));
    _yearCtrl  = TextEditingController(text: '$_year');
    _hourCtrl  = TextEditingController(text: _hour.toString().padLeft(2,'0'));
    _minCtrl   = TextEditingController(text: _minute.toString().padLeft(2,'0'));
  }

  @override
  void dispose() {
    _dayCtrl.dispose(); _monthCtrl.dispose(); _yearCtrl.dispose();
    _hourCtrl.dispose(); _minCtrl.dispose();
    super.dispose();
  }

  int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

  void _notify() {
    final maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) _day = maxDay;
    final date = DateTime(_year, _month, _day);
    final today = DateTime.now();
    if (date.isBefore(DateTime(today.year, today.month, today.day))) return;
    widget.onDateSelected(date);
    widget.onTimeSelected(TimeOfDay(hour: _hour, minute: _minute));
  }

  void _setDay(int v) {
    final max = _daysInMonth(_year, _month);
    _day = v.clamp(1, max);
    _dayCtrl.text = _day.toString().padLeft(2,'0');
    _notify();
  }

  void _setMonth(int v) {
    _month = v.clamp(1, 12);
    _monthCtrl.text = _month.toString().padLeft(2,'0');
    _notify();
  }

  void _setYear(int v) {
    _year = v.clamp(DateTime.now().year, DateTime.now().year + 2);
    _yearCtrl.text = '$_year';
    _notify();
  }

  void _setHour(int v) {
    _hour = (v + 24) % 24;
    _hourCtrl.text = _hour.toString().padLeft(2,'0');
    _notify();
  }

  void _setMinute(int v) {
    _minute = ((v ~/ 5) * 5 + 60) % 60;
    _minCtrl.text = _minute.toString().padLeft(2,'0');
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── ДАТА ──
        Text('Дата', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.6, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Row(children: [
          _Spinner(
            label: 'ДД', ctrl: _dayCtrl, width: 56,
            onUp: () => _setDay(_day + 1),
            onDown: () => _setDay(_day - 1),
            onType: (s) { final v = int.tryParse(s); if (v != null) _setDay(v); },
            primary: primary,
          ),
          _sep('/'),
          _Spinner(
            label: 'ММ', ctrl: _monthCtrl, width: 56,
            onUp: () => _setMonth(_month + 1),
            onDown: () => _setMonth(_month - 1),
            onType: (s) { final v = int.tryParse(s); if (v != null) _setMonth(v); },
            primary: primary,
            hint: _monthNames[_month - 1],
          ),
          _sep('/'),
          _Spinner(
            label: 'ГГГГ', ctrl: _yearCtrl, width: 76,
            onUp: () => _setYear(_year + 1),
            onDown: () => _setYear(_year - 1),
            onType: (s) { final v = int.tryParse(s); if (v != null && s.length == 4) _setYear(v); },
            primary: primary,
          ),
        ]),

        const SizedBox(height: 16),
        Divider(height: 1, color: Colors.grey[100]),
        const SizedBox(height: 12),

        // ── ВРЕМЯ ──
        Text('Время', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.6, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Row(children: [
          _Spinner(
            label: 'ЧЧ', ctrl: _hourCtrl, width: 64,
            onUp: () => _setHour(_hour + 1),
            onDown: () => _setHour(_hour - 1),
            onType: (s) { final v = int.tryParse(s); if (v != null) _setHour(v); },
            primary: primary,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
            child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                color: Colors.grey[400])),
          ),
          _Spinner(
            label: 'ММ', ctrl: _minCtrl, width: 64,
            onUp: () => _setMinute(_minute + 5),
            onDown: () => _setMinute(_minute - 5),
            onType: (s) { final v = int.tryParse(s); if (v != null) _setMinute(v); },
            primary: primary,
          ),
        ]),
      ]),
    );
  }

  Widget _sep(String ch) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 18),
    child: Text(ch, style: TextStyle(fontSize: 18, color: Colors.grey[300], fontWeight: FontWeight.w300)),
  );
}

// Один спиннер-поле: стрелка вверх, текстовое поле, стрелка вниз
class _Spinner extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final double width;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final ValueChanged<String> onType;
  final Color primary;
  final String? hint;

  const _Spinner({
    required this.label,
    required this.ctrl,
    required this.width,
    required this.onUp,
    required this.onDown,
    required this.onType,
    required this.primary,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Стрелка вверх
      _arrow(Icons.keyboard_arrow_up_rounded, onUp, primary),
      // Поле
      SizedBox(
        width: width,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            filled: true,
            fillColor: primary.withOpacity(0.04),
          ),
          onChanged: onType,
        ),
      ),
      // Подпись
      const SizedBox(height: 2),
      Text(hint ?? label,
          style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
      // Стрелка вниз
      _arrow(Icons.keyboard_arrow_down_rounded, onDown, primary),
    ]);
  }

  Widget _arrow(IconData icon, VoidCallback onTap, Color color) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Icon(icon, size: 22, color: color.withOpacity(0.5)),
    ),
  );
}

// ─── ЭКРАН: РЕДАКТИРОВАТЬ ЗАЯВКУ ─────────────────────────────────────────────

class _EditRequestScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  final String routeName;
  final VoidCallback? onSaved;
  const _EditRequestScreen({required this.request, required this.routeName, this.onSaved});

  @override
  State<_EditRequestScreen> createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends State<_EditRequestScreen> {
  late DateTime? _selectedDate;
  late TimeOfDay? _selectedTime;
  late String _paymentType;
  late bool _forOther;
  bool _loading = false;

  late final TextEditingController _seatsCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _entranceCtrl;
  late final TextEditingController _destinationCtrl;
  late final TextEditingController _destinationEntranceCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _commentCtrl;
  late final List<_AddrPair> _extraPairs;
  late final List<_AddrPair> _extraDestPairs;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    final date0 = r['departure_date'] != null ? DateTime.tryParse(r['departure_date']) : null;
    _selectedDate = date0;
    _selectedTime = date0 != null ? TimeOfDay(hour: date0.hour, minute: date0.minute) : null;
    _paymentType = r['payment_type'] ?? 'cash';
    _forOther = r['contact_name'] != null || r['contact_phone'] != null;

    _seatsCtrl               = TextEditingController(text: '${r['seats_needed'] ?? 1}');
    _addressCtrl             = TextEditingController(text: r['pickup_address'] ?? '');
    _entranceCtrl            = TextEditingController(text: r['entrance'] ?? '');
    _destinationCtrl         = TextEditingController(text: r['destination_address'] ?? '');
    _destinationEntranceCtrl = TextEditingController(text: r['destination_entrance'] ?? '');
    _contactNameCtrl         = TextEditingController(text: r['contact_name'] ?? '');
    _contactPhoneCtrl        = TextEditingController(text: r['contact_phone'] ?? '');
    _commentCtrl             = TextEditingController(text: r['comment'] ?? '');

    _AddrPair _pairFromItem(dynamic e) {
      if (e is Map) return _AddrPair(addr: (e['address'] ?? '').toString(), entr: (e['entrance'] ?? '').toString());
      return _AddrPair(addr: e.toString());
    }
    _extraPairs     = ((r['extra_pickups']    as List?) ?? []).map(_pairFromItem).toList();
    _extraDestPairs = ((r['extra_destinations'] as List?) ?? []).map(_pairFromItem).toList();
  }

  @override
  void dispose() {
    _seatsCtrl.dispose(); _addressCtrl.dispose(); _entranceCtrl.dispose();
    _destinationCtrl.dispose(); _destinationEntranceCtrl.dispose();
    _contactNameCtrl.dispose(); _contactPhoneCtrl.dispose();
    _commentCtrl.dispose();
    for (final p in _extraPairs) p.dispose();
    for (final p in _extraDestPairs) p.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _selectedTime = t);
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content: const Text('Заявка будет отменена и удалена из активных.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Нет')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Да, отменить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final token = html.window.localStorage['token'];
    if (token == null) return;
    try {
      await Dio().delete(
        '$apiBase/trip-requests/${widget.request['id']}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату и время')),
      );
      return;
    }
    final token = html.window.localStorage['token'];
    if (token == null) return;
    setState(() => _loading = true);

    final departure = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    try {
      await Dio().patch(
        '$apiBase/trip-requests/${widget.request['id']}',
        data: {
          'seats_needed': int.tryParse(_seatsCtrl.text) ?? 1,
          'departure_date': departure.toIso8601String(),
          'pickup_address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          'entrance': _entranceCtrl.text.trim().isEmpty ? null : _entranceCtrl.text.trim(),
          'extra_pickups': _extraPairs.where((p) => p.hasAddress).map((p) => p.toMap()).toList(),
          'destination_address': _destinationCtrl.text.trim().isEmpty ? null : _destinationCtrl.text.trim(),
          'destination_entrance': _destinationEntranceCtrl.text.trim().isEmpty ? null : _destinationEntranceCtrl.text.trim(),
          'extra_destinations': _extraDestPairs.where((p) => p.hasAddress).map((p) => p.toMap()).toList(),
          'payment_type': _paymentType,
          'comment': _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
          'contact_name': _forOther && _contactNameCtrl.text.trim().isNotEmpty
              ? _contactNameCtrl.text.trim() : null,
          'contact_phone': _forOther && _contactPhoneCtrl.text.trim().isNotEmpty
              ? _contactPhoneCtrl.text.trim() : null,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка обновлена'), backgroundColor: Colors.green),
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? hint,
  }) => TextField(
    controller: controller,
    keyboardType: keyboard,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      filled: true,
      fillColor: Colors.white,
    ),
  );

  Widget _tapField({required IconData icon, required String text, required bool filled, required VoidCallback onTap}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: Row(children: [
            Icon(icon, color: filled ? primary : Colors.grey[500]),
            const SizedBox(width: 14),
            Text(text, style: TextStyle(fontSize: 16, color: filled ? Colors.black87 : Colors.grey[500])),
          ]),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.8, color: Colors.grey[500])),
  );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Изменить заявку', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _cancel,
            child: const Text('Отменить заявку', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [

          // Маршрут (только чтение)
          _section('Маршрут'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(children: [
              Icon(Icons.route_outlined, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Text(widget.routeName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ]),
          ),

          // Дата и время
          _section('Дата и время'),
          _DateTimePicker(
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            onDateSelected: (d) => setState(() => _selectedDate = d),
            onTimeSelected: (t) => setState(() => _selectedTime = t),
          ),

          // Адрес подачи
          _section('Откуда забрать (адрес А)'),
          _inputField(controller: _addressCtrl, label: 'Улица и номер дома',
              icon: Icons.location_on_outlined, hint: 'пр. Абилкайыр хана, 15'),
          const SizedBox(height: 10),
          _inputField(controller: _entranceCtrl, label: 'Подъезд (необязательно)',
              icon: Icons.door_front_door_outlined, keyboard: TextInputType.number),

          // Дополнительные адреса подачи
          for (int i = 0; i < _extraPairs.length; i++) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _inputField(
                controller: _extraPairs[i].address,
                label: 'Адрес ${i + 2} (доп. пассажир)',
                icon: Icons.add_location_alt_outlined,
              )),
              IconButton(
                onPressed: () => setState(() {
                  _extraPairs[i].dispose();
                  _extraPairs.removeAt(i);
                }),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 6),
            _inputField(
              controller: _extraPairs[i].entrance,
              label: 'Подъезд (необязательно)',
              icon: Icons.door_front_door_outlined,
              keyboard: TextInputType.number,
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _extraPairs.add(_AddrPair())),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Добавить адрес подачи'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),

          // Адрес назначения
          _section('Куда довезти (адрес Б)'),
          _inputField(controller: _destinationCtrl, label: 'Улица назначения (необязательно)',
              icon: Icons.flag_outlined, hint: 'ул. Маресьева, 5'),
          const SizedBox(height: 10),
          _inputField(controller: _destinationEntranceCtrl, label: 'Подъезд назначения (необязательно)',
              icon: Icons.door_front_door_outlined, keyboard: TextInputType.number),
          for (int i = 0; i < _extraDestPairs.length; i++) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _inputField(
                controller: _extraDestPairs[i].address,
                label: 'Доп. адрес Б ${i + 2}',
                icon: Icons.flag_circle_outlined,
              )),
              IconButton(
                onPressed: () => setState(() {
                  _extraDestPairs[i].dispose();
                  _extraDestPairs.removeAt(i);
                }),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 6),
            _inputField(
              controller: _extraDestPairs[i].entrance,
              label: 'Подъезд (необязательно)',
              icon: Icons.door_front_door_outlined,
              keyboard: TextInputType.number,
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _extraDestPairs.add(_AddrPair())),
            icon: const Icon(Icons.flag_circle_outlined),
            label: const Text('Добавить точку назначения'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),

          // Места
          _section('Количество мест'),
          _inputField(controller: _seatsCtrl, label: 'Мест',
              icon: Icons.event_seat_outlined, keyboard: TextInputType.number),

          // Оплата
          _section('Способ оплаты'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              for (final entry in [
                ('cash',  'Наличные',  Icons.payments_outlined),
                ('card',  'Карта',     Icons.credit_card_outlined),
                ('kaspi', 'Kaspi',     Icons.phone_android_outlined),
              ])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentType = entry.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentType == entry.$1 ? primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(entry.$3, size: 20,
                            color: _paymentType == entry.$1 ? Colors.white : Colors.grey[500]),
                        const SizedBox(height: 4),
                        Text(entry.$2, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _paymentType == entry.$1 ? Colors.white : Colors.grey[600],
                        )),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),

          // Для кого
          _section('Для кого заказ'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              RadioListTile<bool>(
                value: false, groupValue: _forOther,
                onChanged: (v) => setState(() => _forOther = false),
                title: const Text('Для себя'), activeColor: primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              const Divider(height: 1, indent: 16),
              RadioListTile<bool>(
                value: true, groupValue: _forOther,
                onChanged: (v) => setState(() => _forOther = true),
                title: const Text('Для другого человека'), activeColor: primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ]),
          ),
          if (_forOther) ...[
            const SizedBox(height: 10),
            _inputField(controller: _contactNameCtrl, label: 'Имя пассажира',
                icon: Icons.person_outline, hint: 'Мама'),
            const SizedBox(height: 10),
            _inputField(controller: _contactPhoneCtrl, label: 'Номер телефона пассажира',
                icon: Icons.phone_outlined, keyboard: TextInputType.phone,
                hint: '+7 777 000 00 00'),
          ],

          // Комментарий
          _section('Комментарий водителю'),
          _inputField(controller: _commentCtrl, label: 'Комментарий (необязательно)',
              icon: Icons.comment_outlined, maxLines: 3,
              hint: 'Буду у парадного входа'),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary, foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Сохранить изменения',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ЭКРАН: СОЗДАТЬ ЗАЯВКУ ───────────────────────────────────────────────────

class _CreateRequestScreen extends StatefulWidget {
  final List<Map<String, dynamic>> routes;
  final String? Function() getToken;
  final VoidCallback onCreated;
  const _CreateRequestScreen({required this.routes, required this.getToken, required this.onCreated});

  @override
  State<_CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<_CreateRequestScreen> {
  Map<String, dynamic>? _selectedRoute;
  DateTime? _selectedDate  = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String _paymentType = 'cash';
  bool _forOther = false;

  final _seatsCtrl               = TextEditingController(text: '1');
  final _addressCtrl             = TextEditingController();
  final _entranceCtrl            = TextEditingController();
  final _destinationCtrl         = TextEditingController();
  final _destinationEntranceCtrl = TextEditingController();
  final _contactNameCtrl         = TextEditingController();
  final _contactPhoneCtrl        = TextEditingController();
  final _commentCtrl             = TextEditingController();
  final List<_AddrPair> _extraPairs     = [];
  final List<_AddrPair> _extraDestPairs = [];

  bool _loading = false;

  @override
  void dispose() {
    _seatsCtrl.dispose();
    _addressCtrl.dispose(); _entranceCtrl.dispose();
    _destinationCtrl.dispose(); _destinationEntranceCtrl.dispose();
    _contactNameCtrl.dispose(); _contactPhoneCtrl.dispose();
    _commentCtrl.dispose();
    for (final p in _extraPairs) p.dispose();
    for (final p in _extraDestPairs) p.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    if (_selectedRoute == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите маршрут, дату и время')),
      );
      return;
    }
    final token = widget.getToken();
    if (token == null) return;
    setState(() => _loading = true);

    final departure = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    try {
      await Dio().post(
        '$apiBase/trip-requests/',
        data: {
          'route_id': _selectedRoute!['id'],
          'seats_needed': int.tryParse(_seatsCtrl.text) ?? 1,
          'departure_date': departure.toIso8601String(),
          'pickup_address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          'entrance': _entranceCtrl.text.trim().isEmpty ? null : _entranceCtrl.text.trim(),
          'extra_pickups': _extraPairs.where((p) => p.hasAddress).map((p) => p.toMap()).toList(),
          'destination_address': _destinationCtrl.text.trim().isEmpty ? null : _destinationCtrl.text.trim(),
          'destination_entrance': _destinationEntranceCtrl.text.trim().isEmpty ? null : _destinationEntranceCtrl.text.trim(),
          'extra_destinations': _extraDestPairs.where((p) => p.hasAddress).map((p) => p.toMap()).toList(),
          'payment_type': _paymentType,
          'comment': _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
          if (_forOther) ...{
            'contact_name': _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim(),
            'contact_phone': _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim(),
          },
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } on DioException catch (e) {
      if (mounted) {
        if (e.response?.statusCode == 401) {
          html.window.localStorage.remove('token');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сессия истекла. Войдите снова.'), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
          context.go('/login');
        } else {
          final msg = e.response?.data?['detail'] ?? e.message ?? 'Ошибка сети';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $msg')));
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Поле ввода с иконкой
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  // Поле-кнопка (дата/время)
  Widget _tapField({required IconData icon, required String text, required bool filled, required VoidCallback onTap}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: Row(children: [
            Icon(icon, color: filled ? primary : Colors.grey[500]),
            const SizedBox(width: 14),
            Text(text,
                style: TextStyle(fontSize: 16, color: filled ? Colors.black87 : Colors.grey[500])),
          ]),
        ),
      ),
    );
  }

  // Разделитель-заголовок секции
  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.8, color: Colors.grey[500])),
  );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final canSubmit = _selectedRoute != null && _selectedDate != null && _selectedTime != null && !_loading;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Новая заявка', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [

          // ── МАРШРУТ ──
          _section('Маршрут'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedRoute,
              decoration: InputDecoration(
                labelText: 'Откуда → Куда',
                prefixIcon: const Icon(Icons.route_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
              items: widget.routes.map((r) => DropdownMenuItem(
                value: r,
                child: Text('${r['city_from']} → ${r['city_to']}'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedRoute = v),
              hint: const Text('Выберите маршрут'),
            ),
          ),

          // ── ДАТА И ВРЕМЯ ──
          _section('Дата и время'),
          _DateTimePicker(
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            onDateSelected: (d) => setState(() => _selectedDate = d),
            onTimeSelected: (t) => setState(() => _selectedTime = t),
          ),

          // ── АДРЕС ПОДАЧИ ──
          _section('Откуда забрать (адрес А)'),
          _inputField(
            controller: _addressCtrl,
            label: 'Улица и номер дома',
            icon: Icons.location_on_outlined,
            hint: 'пр. Абилкайыр хана, 15',
          ),
          const SizedBox(height: 10),
          _inputField(
            controller: _entranceCtrl,
            label: 'Подъезд (необязательно)',
            icon: Icons.door_front_door_outlined,
            keyboard: TextInputType.number,
            hint: '2',
          ),

          // Дополнительные адреса подачи
          for (int i = 0; i < _extraPairs.length; i++) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _inputField(
                controller: _extraPairs[i].address,
                label: 'Адрес ${i + 2} (доп. пассажир)',
                icon: Icons.add_location_alt_outlined,
              )),
              IconButton(
                onPressed: () => setState(() {
                  _extraPairs[i].dispose();
                  _extraPairs.removeAt(i);
                }),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 6),
            _inputField(
              controller: _extraPairs[i].entrance,
              label: 'Подъезд (необязательно)',
              icon: Icons.door_front_door_outlined,
              keyboard: TextInputType.number,
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _extraPairs.add(_AddrPair())),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Добавить адрес подачи'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),

          // ── АДРЕС НАЗНАЧЕНИЯ ──
          _section('Куда довезти (адрес Б)'),
          _inputField(
            controller: _destinationCtrl,
            label: 'Улица назначения (необязательно)',
            icon: Icons.flag_outlined,
            hint: 'ул. Маресьева, 5',
          ),
          const SizedBox(height: 10),
          _inputField(
            controller: _destinationEntranceCtrl,
            label: 'Подъезд назначения (необязательно)',
            icon: Icons.door_front_door_outlined,
            keyboard: TextInputType.number,
          ),
          for (int i = 0; i < _extraDestPairs.length; i++) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _inputField(
                controller: _extraDestPairs[i].address,
                label: 'Доп. адрес Б ${i + 2}',
                icon: Icons.flag_circle_outlined,
              )),
              IconButton(
                onPressed: () => setState(() {
                  _extraDestPairs[i].dispose();
                  _extraDestPairs.removeAt(i);
                }),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 6),
            _inputField(
              controller: _extraDestPairs[i].entrance,
              label: 'Подъезд (необязательно)',
              icon: Icons.door_front_door_outlined,
              keyboard: TextInputType.number,
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _extraDestPairs.add(_AddrPair())),
            icon: const Icon(Icons.flag_circle_outlined),
            label: const Text('Добавить точку назначения'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),

          // ── МЕСТА ──
          _section('Количество мест'),
          _inputField(
            controller: _seatsCtrl,
            label: 'Мест',
            icon: Icons.event_seat_outlined,
            keyboard: TextInputType.number,
          ),

          // ── ОПЛАТА ──
          _section('Способ оплаты'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              for (final entry in [
                ('cash',  'Наличные',  Icons.payments_outlined),
                ('card',  'Карта',     Icons.credit_card_outlined),
                ('kaspi', 'Kaspi',     Icons.phone_android_outlined),
              ]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentType = entry.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentType == entry.$1 ? primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(entry.$3,
                            size: 20,
                            color: _paymentType == entry.$1 ? Colors.white : Colors.grey[500]),
                        const SizedBox(height: 4),
                        Text(entry.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _paymentType == entry.$1 ? Colors.white : Colors.grey[600],
                            )),
                      ]),
                    ),
                  ),
                ),
              ],
            ]),
          ),

          // ── ДЛЯ КОГО ──
          _section('Для кого заказ'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              RadioListTile<bool>(
                value: false,
                groupValue: _forOther,
                onChanged: (v) => setState(() => _forOther = false),
                title: const Text('Для себя'),
                activeColor: primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              const Divider(height: 1, indent: 16),
              RadioListTile<bool>(
                value: true,
                groupValue: _forOther,
                onChanged: (v) => setState(() => _forOther = true),
                title: const Text('Для другого человека'),
                activeColor: primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ]),
          ),

          if (_forOther) ...[
            const SizedBox(height: 10),
            _inputField(
              controller: _contactNameCtrl,
              label: 'Имя пассажира',
              icon: Icons.person_outline,
              hint: 'Мама',
            ),
            const SizedBox(height: 10),
            _inputField(
              controller: _contactPhoneCtrl,
              label: 'Номер телефона пассажира',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
              hint: '+7 777 000 00 00',
            ),
          ],

          // ── КОММЕНТАРИЙ ──
          _section('Комментарий водителю'),
          _inputField(
            controller: _commentCtrl,
            label: 'Комментарий (необязательно)',
            icon: Icons.comment_outlined,
            maxLines: 3,
            hint: 'Буду у парадного входа, позвоните за 5 минут',
          ),

          const SizedBox(height: 28),

          // ── КНОПКА ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: canSubmit ? 2 : 0,
              ),
              child: _loading
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Отправить заявку',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ТАБ: ПОПУТКИ (поиск готовых поездок водителей) ─────────────────────────

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
      final res = await Dio().get(
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
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedRoute,
                  decoration: InputDecoration(
                    labelText: 'Куда едете?',
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
        ),
        const Divider(height: 1),
        Expanded(
          child: !_searched
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Выберите маршрут', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('Найдём доступные поездки', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                )
              : _trips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 72, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Поездок по этому маршруту нет', style: TextStyle(color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Text('Создайте заявку во вкладке "Поездки"',
                              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
                    )
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
}

// ─── КАРТОЧКА ПОЕЗДКИ (для вкладки Попутки) ─────────────────────────────────

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String routeName;
  final String? Function() getToken;
  final VoidCallback onBooked;
  const _TripCard({required this.trip, required this.routeName, required this.getToken, required this.onBooked});

  void _openBookingForm(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _BookingFormScreen(
        trip: trip,
        routeName: routeName,
        getToken: getToken,
        onBooked: onBooked,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final date = trip['departure_time'] != null ? DateTime.tryParse(trip['departure_time']) : null;
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
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.directions_car, color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(routeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (date != null)
                    Text(
                      '${date.day}.${date.month}.${date.year} в ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                ]),
              ),
              Text('${trip['price_per_seat']} ₸',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.event_seat_outlined, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('${trip['seats_available']} мест свободно', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _openBookingForm(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Забронировать'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
