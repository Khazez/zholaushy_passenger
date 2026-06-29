import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'driver_profile_screen.dart';
import 'info_screens.dart';
import '../config.dart';
import '../theme.dart';
import '../app_state.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _getToken() => html.window.localStorage['token'];
  String  _getName()  => html.window.localStorage['name'] ?? 'Водитель';

  void _logout() {
    html.window.localStorage.remove('token');
    html.window.localStorage.remove('mode');
    html.window.localStorage['theme'] = 'light';
    AppState.themeNotifier.value = ThemeMode.light;
    context.go('/login');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVerification());
  }

  Future<void> _checkVerification() async {
    final token = _getToken();
    if (token == null) { if (mounted) context.go('/login'); return; }
    try {
      final res = await Dio().get(
        '$kApiBase/drivers/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.data['data']['is_verified'] != true && mounted) {
        context.go('/pending');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && mounted) {
        context.go('/car-info');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final name = _getName();
    final initials = name.trim().split(' ')
        .where((p) => p.isNotEmpty).take(2)
        .map((p) => p[0].toUpperCase()).join();

    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        flexibleSpace: const AppBarOrnament(),
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: kGradientVertical,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            child: Center(
              child: Text(initials, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white,
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ZHOLAUSHY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
              Text(name, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
            ]),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              switch (val) {
                case 'profile':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverProfileScreen()));
                  break;
                case 'support':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()));
                  break;
                case 'settings':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  break;
                case 'about':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profile',  child: ListTile(leading: Icon(Icons.person_outline),   title: Text('Профиль'),      contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuItem(value: 'support',  child: ListTile(leading: Icon(Icons.help_outline),     title: Text('Поддержка'),    contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Настройки'),    contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuItem(value: 'about',    child: ListTile(leading: Icon(Icons.info_outline),      title: Text('О приложении'), contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout',   child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Выйти', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero, dense: true)),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_outlined),               text: 'Заявки'),
            Tab(icon: Icon(Icons.directions_car_outlined),          text: 'Поездки'),
            Tab(icon: Icon(Icons.history_outlined),                 text: 'Отклики'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined),  text: 'Баланс'),
          ],
        ),
      ),
      body: BodyOrnament(child: TabBarView(
        controller: _tabController,
        children: [
          _RequestsTab(getToken: _getToken),
          _MyTripsTab(getToken: _getToken),
          _MyOffersTab(getToken: _getToken),
          _BalanceTab(getToken: _getToken),
        ],
      )),
    );
  }
}

// ─── ТАБ 1: ОТКРЫТЫЕ ЗАЯВКИ ПАССАЖИРОВ ──────────────────────────────────────

class _RequestsTab extends StatefulWidget {
  final String? Function() getToken;
  const _RequestsTab({required this.getToken});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  List<dynamic> _requests = [];
  List<dynamic> _routes   = [];
  int? _selectedRouteId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _loadRequests();
  }

  Future<void> _loadRoutes() async {
    try {
      final res = await Dio().get('$kApiBase/routes/');
      final data = res.data;
      final list = data is Map ? (data['data'] ?? []) : data;
      if (mounted) setState(() => _routes = List<Map<String, dynamic>>.from(list));
    } catch (_) {}
  }

  Future<void> _loadRequests() async {
    if (mounted) setState(() => _loading = true);
    final token = widget.getToken();
    if (token == null) return;
    try {
      final params = _selectedRouteId != null ? {'route_id': _selectedRouteId} : null;
      final res = await Dio().get(
        '$kApiBase/trip-requests/',
        queryParameters: params,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 8));
      if (mounted) setState(() {
        _requests = res.data is List ? res.data : [];
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(children: [

      if (_routes.isNotEmpty)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('Все', null, primary),
              ..._routes.map((r) => _filterChip(
                '${r['city_from']} → ${r['city_to']}',
                r['id'] as int,
                primary,
              )),
            ]),
          ),
        ),

      const Divider(height: 1),

      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inbox_outlined, size: 72, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Нет открытых заявок', style: TextStyle(color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    Text('Пассажиры ещё не создали заявки',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _loadRequests,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Обновить'),
                    ),
                  ]))
                : RefreshIndicator(
                    onRefresh: _loadRequests,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (_, i) => _PassengerRequestCard(
                        request: _requests[i],
                        getToken: widget.getToken,
                        onOffered: _loadRequests,
                        routes: _routes,
                      ),
                    ),
                  ),
      ),
    ]);
  }

  Widget _filterChip(String label, int? routeId, Color primary) {
    final selected = _selectedRouteId == routeId;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRouteId = routeId);
        _loadRequests();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _PassengerRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final String? Function() getToken;
  final VoidCallback onOffered;
  final List<dynamic> routes;

  const _PassengerRequestCard({
    required this.request,
    required this.getToken,
    required this.onOffered,
    required this.routes,
  });

  @override
  State<_PassengerRequestCard> createState() => _PassengerRequestCardState();
}

class _PassengerRequestCardState extends State<_PassengerRequestCard> {
  bool _expanded = false;
  bool _offering = false;
  bool _alreadyOffered = false;

  String _routeName() {
    final r = widget.request;
    if (r['route_name'] != null) return r['route_name'];
    final route = widget.routes.where((rt) => rt['id'] == r['route_id']).firstOrNull;
    if (route != null) return '${route['city_from']} → ${route['city_to']}';
    return 'Маршрут #${r['route_id']}';
  }

  Future<void> _sendOffer() async {
    final priceCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ваша цена за место'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Заявка #${widget.request['id']} · ${_routeName()}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: priceCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Например: 3500',
              suffixText: '₸',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
            child: const Text('Откликнуться'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
    if (price == null || price <= 0) return;

    setState(() => _offering = true);
    final token = widget.getToken();
    try {
      await Dio().post(
        '$kApiBase/trip-requests/offers',
        data: {'request_id': widget.request['id'], 'price_per_seat': price},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      ).timeout(const Duration(seconds: 8));
      setState(() => _alreadyOffered = true);
      widget.onOffered();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отклик отправлен!'), backgroundColor: Colors.green),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $msg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _offering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final req      = widget.request;
    final date     = req['departure_date'] != null ? DateTime.tryParse(req['departure_date']) : null;
    final payment  = req['payment_type'] ?? 'cash';
    final payLabel = payment == 'card' ? 'Карта' : payment == 'kaspi' ? 'Kaspi' : 'Наличные';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.route_outlined, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_routeName(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (date != null)
                  Text(
                    '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}  '
                    '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${req['seats_needed'] ?? 1} мест',
                      style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                if (req['passenger_avg_rating'] != null) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 13, color: Colors.amber[600]),
                    const SizedBox(width: 2),
                    Text('${req['passenger_avg_rating']}',
                        style: TextStyle(fontSize: 12, color: Colors.amber[800], fontWeight: FontWeight.w600)),
                  ]),
                ],
                const SizedBox(height: 4),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[400], size: 18),
              ]),
            ]),

            if (_expanded) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
              const SizedBox(height: 12),

              Wrap(spacing: 20, runSpacing: 8, children: [
                _detail(Icons.payments_outlined, payLabel),
                if (req['contact_name'] != null)
                  _detail(Icons.person_outlined, req['contact_name']),
                if (req['contact_phone'] != null)
                  _detail(Icons.phone_outlined, req['contact_phone']),
              ]),

              Builder(builder: (_) {
                final address      = req['pickup_address'] as String?;
                final entrance     = req['entrance'] as String?;
                final extraPickups = (req['extra_pickups']    as List?) ?? [];
                final destAddr     = req['destination_address'] as String?;
                final destEntrance = req['destination_entrance'] as String?;
                final extraDests   = (req['extra_destinations'] as List?) ?? [];
                final hasAny = (address?.isNotEmpty ?? false) || extraPickups.isNotEmpty
                    || (destAddr?.isNotEmpty ?? false) || extraDests.isNotEmpty;
                if (!hasAny) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (address != null && address.isNotEmpty)
                      _addrLine2(Icons.location_on_outlined, Colors.blue.shade600, 'А',
                        address + (entrance != null && entrance.isNotEmpty ? ', подъезд $entrance' : '')),
                    for (int i = 0; i < extraPickups.length; i++) ...[
                      const SizedBox(height: 3),
                      _addrLine2(Icons.add_location_alt_outlined, Colors.blue.shade400, 'А${i+2}',
                        _addrLine(extraPickups[i])),
                    ],
                    if (destAddr != null && destAddr.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _addrLine2(Icons.flag_outlined, Colors.green.shade700, 'Б',
                        destAddr + (destEntrance != null && destEntrance.isNotEmpty ? ', подъезд $destEntrance' : '')),
                    ],
                    for (int i = 0; i < extraDests.length; i++) ...[
                      const SizedBox(height: 3),
                      _addrLine2(Icons.flag_circle_outlined, Colors.green.shade400, 'Б${i+2}',
                        _addrLine(extraDests[i])),
                    ],
                  ]),
                );
              }),

              if (req['comment'] != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.comment_outlined, size: 15, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(req['comment'],
                        style: TextStyle(color: Colors.amber[900], fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              GestureDetector(
                onTap: (_offering || _alreadyOffered) ? null : _sendOffer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: _alreadyOffered || _offering ? null : kGradient,
                    color: _alreadyOffered ? Colors.grey[400] : (_offering ? Colors.grey[300] : null),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_offering)
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    else
                      Icon(_alreadyOffered ? Icons.check_circle : Icons.send_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _alreadyOffered ? 'Отклик отправлен' : 'Откликнуться',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: Colors.grey[500]),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
  ]);

  Widget _addrLine2(IconData icon, Color color, String label, String text) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 20, height: 20,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Center(child: Text(label,
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color))),
      ),
      const SizedBox(width: 6),
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 12))),
    ]);
}

// ─── ТАБ 2: МОИ ОТКЛИКИ ──────────────────────────────────────────────────────

class _MyOffersTab extends StatefulWidget {
  final String? Function() getToken;
  const _MyOffersTab({required this.getToken});

  @override
  State<_MyOffersTab> createState() => _MyOffersTabState();
}

class _MyOffersTabState extends State<_MyOffersTab> {
  List<dynamic> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = widget.getToken();
    if (token == null) return;
    try {
      final res = await Dio().get(
        '$kApiBase/trips/my-offers',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 8));
      final all = res.data is List ? res.data as List : [];
      setState(() {
        _offers  = all.where((o) => o['request_status'] != 'cancelled').toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_offers.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.send_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('Нет откликов', style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text('Откликнитесь на заявку пассажира', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        const SizedBox(height: 20),
        TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Обновить')),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _offers.length,
        itemBuilder: (_, i) => _OfferCard(
          offer: _offers[i],
          primary: primary,
          getToken: widget.getToken,
          onCancelled: _load,
        ),
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  final Map<String, dynamic> offer;
  final Color primary;
  final String? Function() getToken;
  final VoidCallback onCancelled;
  const _OfferCard({
    required this.offer,
    required this.primary,
    required this.getToken,
    required this.onCancelled,
  });

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  bool _expanded = false;
  bool _cancelling = false;

  Future<void> _cancelOffer() async {
    final offerId = widget.offer['offer_id'] as int?;
    if (offerId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Отозвать отклик?'),
        content: const Text('Ваш отклик будет удалён, пассажир его больше не увидит.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Отозвать'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancelling = true);
    final token = widget.getToken();
    try {
      await Dio().delete(
        '$kApiBase/trip-requests/offers/$offerId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 8));
      widget.onCancelled();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.response?.data?['detail'] ?? 'Ошибка'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o          = widget.offer;
    final primary    = widget.primary;
    final isAccepted = (o['request_status'] ?? 'open') == 'accepted';
    final routeName  = o['route_name'] ?? '—';
    final dep        = o['departure_date'] != null ? DateTime.tryParse(o['departure_date']) : null;
    final price      = o['price_per_seat'];
    final address     = o['pickup_address'] as String?;
    final entrance    = o['entrance'] as String?;
    final extraPickups  = (o['extra_pickups']  as List?) ?? [];
    final destAddr    = o['destination_address'] as String?;
    final destEntrance= o['destination_entrance'] as String?;
    final extraDests  = (o['extra_destinations'] as List?) ?? [];
    final contactName = o['contact_name'] as String?;
    final contactPhone= o['contact_phone'] as String?;
    final pasPhone    = o['passenger_phone'] as String?;
    final payment     = o['payment_type'] ?? 'cash';
    final payLabel    = payment == 'card' ? 'Карта' : payment == 'kaspi' ? 'Kaspi' : 'Наличные';
    final comment     = o['comment'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAccepted ? Colors.green.shade300 : Colors.grey.withValues(alpha: 0.2),
          width: isAccepted ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (isAccepted ? Colors.green : primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAccepted ? Icons.check_circle_outline : Icons.pending_outlined,
                  color: isAccepted ? Colors.green : primary, size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(routeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (dep != null)
                  Text(
                    '${dep.day.toString().padLeft(2,'0')}.${dep.month.toString().padLeft(2,'0')}.${dep.year}  '
                    '${dep.hour.toString().padLeft(2,'0')}:${dep.minute.toString().padLeft(2,'0')}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                Text(
                  '${o['seats_needed'] ?? 1} мест'
                  '${price != null ? '  ·  ${price.toStringAsFixed(0)} ₸/место' : ''}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isAccepted ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAccepted ? 'Принят!' : 'Ожидает',
                    style: TextStyle(
                      color: isAccepted ? Colors.green[700] : Colors.orange[700],
                      fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[400], size: 18),
              ]),
            ]),

            if (_expanded) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAccepted ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAccepted ? Colors.green.shade100 : Colors.blue.shade100),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.person_outline, size: 14,
                        color: isAccepted ? Colors.green[700] : Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text('Пассажир',
                        style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12,
                          color: isAccepted ? Colors.green[700] : Colors.blue[700],
                        )),
                  ]),
                  const SizedBox(height: 6),
                  if (contactName != null && contactName.isNotEmpty)
                    _row(Icons.badge_outlined, contactName),
                  _row(Icons.payments_outlined, payLabel),
                  const SizedBox(height: 8),
                  _phoneButtons(contactPhone ?? pasPhone ?? ''),
                ]),
              ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text('Маршрут пассажира',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12,
                            color: Colors.grey[700])),
                  ]),
                  const SizedBox(height: 8),
                  if (address != null && address.isNotEmpty)
                    _addrOfferRow(Icons.location_on_outlined, Colors.blue.shade600,
                      address + (entrance != null && entrance.isNotEmpty ? ', подъезд $entrance' : ''), 'А')
                  else
                    Row(children: [
                      Icon(Icons.location_off_outlined, size: 13, color: Colors.orange[400]),
                      const SizedBox(width: 6),
                      Text('Адрес подачи не указан',
                          style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                    ]),
                  for (int i = 0; i < extraPickups.length; i++) ...[
                    const SizedBox(height: 4),
                    _addrOfferRow(Icons.add_location_alt_outlined, Colors.blue.shade400,
                        _addrLine(extraPickups[i]), 'А${i + 2}'),
                  ],
                  if (destAddr != null && destAddr.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _addrOfferRow(Icons.flag_outlined, Colors.green.shade700,
                      destAddr + (destEntrance != null && destEntrance.isNotEmpty ? ', подъезд $destEntrance' : ''), 'Б'),
                  ],
                  for (int i = 0; i < extraDests.length; i++) ...[
                    const SizedBox(height: 4),
                    _addrOfferRow(Icons.flag_circle_outlined, Colors.green.shade400,
                        _addrLine(extraDests[i]), 'Б${i + 2}'),
                  ],
                ]),
              ),

              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade100),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.comment_outlined, size: 14, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(comment,
                        style: TextStyle(color: Colors.amber[900], fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelOffer,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Отозвать отклик'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: Colors.grey[600]),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _addrOfferRow(IconData icon, Color color, String text, String label) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 20, height: 20,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Center(child: Text(label,
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color))),
      ),
      const SizedBox(width: 6),
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 12))),
    ]);
}

// ─── ТАБ 2: МОИ ПОЕЗДКИ ──────────────────────────────────────────────────────

class _MyTripsTab extends StatefulWidget {
  final String? Function() getToken;
  const _MyTripsTab({required this.getToken});

  @override
  State<_MyTripsTab> createState() => _MyTripsTabState();
}

class _MyTripsTabState extends State<_MyTripsTab> {
  List<dynamic> _trips    = [];
  List<dynamic> _routes   = [];
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _load();
  }

  Future<void> _loadRoutes() async {
    try {
      final res = await Dio().get('$kApiBase/routes/');
      final data = res.data;
      setState(() => _routes = data is Map ? (data['data'] ?? []) : data);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = widget.getToken();
    if (token == null) return;
    try {
      final headers = {'Authorization': 'Bearer $token'};
      final results = await Future.wait([
        Dio().get('$kApiBase/trips/', queryParameters: {'my': true},
            options: Options(headers: headers)).timeout(const Duration(seconds: 8)),
        Dio().get('$kApiBase/bookings/for-driver',
            options: Options(headers: headers)).timeout(const Duration(seconds: 8)),
      ]);
      final tripsData    = results[0].data;
      final bookingsData = results[1].data;
      setState(() {
        _trips    = tripsData is Map ? (tripsData['data'] ?? []) : (tripsData is List ? tripsData : []);
        _bookings = bookingsData is List ? bookingsData : [];
        _loading  = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _complete(int tripId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Завершить поездку?'),
        content: const Text('Пассажиры смогут оставить оценку после завершения.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final token = widget.getToken();
    try {
      await Dio().patch(
        '$kApiBase/trips/$tripId/complete',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final passengers = _bookings
          .where((b) => b['trip_id'] == tripId && b['passenger_id'] != null)
          .toList();

      _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Поездка завершена!'), backgroundColor: Colors.green),
        );
      }

      for (final b in passengers) {
        if (!mounted) break;
        await _showRatePassengerDialog(tripId, b);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['detail'] ?? 'Ошибка'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showRatePassengerDialog(int tripId, Map<String, dynamic> booking) async {
    final passengerName = booking['passenger_name'] as String? ?? 'пассажира';
    final passengerId   = booking['passenger_id'] as int?;
    if (passengerId == null) return;

    int selectedScore = 0;
    final commentCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Оцените $passengerName'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setDialog(() => selectedScore = star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      star <= selectedScore ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber, size: 40,
                    ),
                  ),
                );
              }),
            ),
            if (selectedScore > 0) ...[
              const SizedBox(height: 6),
              Text(
                ['', 'Очень плохо', 'Плохо', 'Нормально', 'Хорошо', 'Отлично!'][selectedScore],
                style: TextStyle(color: Colors.amber[700], fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Комментарий (необязательно)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Пропустить'),
            ),
            ElevatedButton(
              onPressed: selectedScore == 0 ? null : () async {
                final token = widget.getToken();
                final comment = commentCtrl.text.trim();
                try {
                  await Dio().post(
                    '$kApiBase/ratings/',
                    data: {
                      'trip_id': tripId,
                      'to_user_id': passengerId,
                      'score': selectedScore,
                      if (comment.isNotEmpty) 'comment': comment,
                    },
                    options: Options(
                      headers: {'Authorization': 'Bearer $token'},
                      contentType: 'application/json',
                    ),
                  );
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700], foregroundColor: Colors.white),
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );

    commentCtrl.dispose();
  }

  Future<void> _departing(int tripId) async {
    final token = widget.getToken();
    try {
      await Dio().patch(
        '$kApiBase/trips/$tripId/departing',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        final idx = _trips.indexWhere((t) => t['id'] == tripId);
        if (idx != -1) _trips[idx] = {..._trips[idx], 'is_departed': true};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Пассажиры уведомлены о выезде'), backgroundColor: Colors.blue[700]),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['detail'] ?? 'Ошибка'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _arrived(int tripId) async {
    final token = widget.getToken();
    try {
      await Dio().patch(
        '$kApiBase/trips/$tripId/arrived',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        final idx = _trips.indexWhere((t) => t['id'] == tripId);
        if (idx != -1) _trips[idx] = {..._trips[idx], 'is_arrived': true};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пассажиры уведомлены о прибытии'), backgroundColor: Colors.orange),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['detail'] ?? 'Ошибка'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancel(int tripId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Отменить поездку?'),
        content: const Text('Поездка будет отменена. Пассажиры с бронями будут уведомлены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final token = widget.getToken();
    try {
      await Dio().patch(
        '$kApiBase/trips/$tripId/cancel',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Поездка отменена'), backgroundColor: Colors.orange),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['detail'] ?? 'Ошибка'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _routeName(int? routeId) {
    if (routeId == null) return '—';
    final r = _routes.where((rt) => rt['id'] == routeId).firstOrNull;
    return r != null ? '${r['city_from']} → ${r['city_to']}' : 'Маршрут #$routeId';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: context.bgC,
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          gradient: kGradient,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => _CreateTripScreen(getToken: widget.getToken, routes: _routes),
            ));
            _load();
          },
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add),
          label: const Text('Новая поездка'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.directions_car_outlined, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Нет поездок', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text('Создайте поездку чтобы откликаться на заявки',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 80),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _trips.length,
                    itemBuilder: (_, i) {
                      final t = _trips[i];
                      final dep = t['departure_time'] != null ? DateTime.tryParse(t['departure_time']) : null;
                      final isActive    = t['status'] == 'active';
                      final isCompleted = t['status'] == 'completed';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isCompleted ? Colors.grey.withValues(alpha: 0.2)
                                : isActive ? primary.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(
                                _routeName(t['route_id'] as int?),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              )),
                              _statusBadge(t['status'] ?? 'active'),
                            ]),
                            const SizedBox(height: 10),
                            Wrap(spacing: 20, runSpacing: 6, children: [
                              if (dep != null)
                                _info(Icons.access_time_outlined,
                                    '${dep.day.toString().padLeft(2,'0')}.${dep.month.toString().padLeft(2,'0')}.${dep.year}  '
                                    '${dep.hour.toString().padLeft(2,'0')}:${dep.minute.toString().padLeft(2,'0')}'),
                              _info(Icons.event_seat_outlined, '${t['seats_available']}/${t['seats_total']} мест'),
                              _info(Icons.payments_outlined, '${t['price_per_seat']?.toStringAsFixed(0) ?? '—'} ₸/место'),
                            ]),
                            if (isActive) ...[
                              const SizedBox(height: 12),
                              Builder(builder: (_) {
                                final tripId   = t['id'] as int;
                                final departed = t['is_departed'] == true;
                                final arrived  = t['is_arrived'] == true;
                                if (arrived) return const SizedBox.shrink();
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: departed
                                        ? () => _arrived(tripId)
                                        : () => _departing(tripId),
                                    icon: Icon(
                                      departed ? Icons.location_on : Icons.directions_car,
                                      size: 18,
                                    ),
                                    label: Text(departed ? 'Подъехал' : 'Выезжаю'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: departed ? Colors.orange[700] : Colors.blue[700],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _complete(t['id'] as int),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('Завершить'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(color: Colors.green),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _cancel(t['id'] as int),
                                    icon: const Icon(Icons.cancel_outlined, size: 18),
                                    label: const Text('Отменить'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                            Builder(builder: (_) {
                              final tripBookings = _bookings
                                  .where((b) =>
                                      b['trip_id'] == t['id'] &&
                                      b['booking_status'] != 'cancelled')
                                  .toList();
                              if (tripBookings.isEmpty) return const SizedBox.shrink();
                              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Divider(height: 20, thickness: 0.5),
                                Row(children: [
                                  Icon(Icons.people_outline, size: 14, color: primary),
                                  const SizedBox(width: 6),
                                  Text('Пассажиры (${tripBookings.length})',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: primary)),
                                ]),
                                const SizedBox(height: 8),
                                for (final b in tripBookings) _PassengerRow(booking: b),
                              ]);
                            }),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _statusBadge(String status) {
    final (label, color) = switch (status) {
      'completed' => ('Завершена', Colors.grey),
      'cancelled' => ('Отменена', Colors.red),
      _ => ('Активна', Colors.green),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: Colors.grey[500]),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
  ]);
}

// ─── ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ──────────────────────────────────────────────────

Widget _phoneButtons(String phone) {
  if (phone.isEmpty) return const SizedBox.shrink();
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => html.window.open('tel:$phone', '_self'),
      icon: const Icon(Icons.phone_outlined, size: 14),
      label: const Text('Позвонить', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue[700],
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 6),
        minimumSize: Size.zero,
      ),
    ),
  );
}

String _addrLine(dynamic item) {
  if (item is Map) {
    final addr = (item['address'] ?? '').toString();
    final entr = item['entrance'];
    return (entr != null && entr.toString().isNotEmpty)
        ? '$addr, подъезд $entr'
        : addr;
  }
  return item.toString();
}

// ─── КАРТОЧКА ПАССАЖИРА ───────────────────────────────────────────────────────

class _PassengerRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _PassengerRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final name        = (booking['contact_name'] as String?)?.isNotEmpty == true
        ? booking['contact_name'] as String
        : booking['passenger_name'] as String? ?? '—';
    final phone       = (booking['contact_phone'] as String?)?.isNotEmpty == true
        ? booking['contact_phone'] as String
        : booking['passenger_phone'] as String? ?? '—';
    final address     = booking['pickup_address'] as String?;
    final entrance    = booking['entrance'] as String?;
    final extraPickups  = (booking['extra_pickups']  as List?) ?? [];
    final destAddr    = booking['destination_address'] as String?;
    final destEntrance= booking['destination_entrance'] as String?;
    final extraDests  = (booking['extra_destinations'] as List?) ?? [];
    final comment     = booking['comment'] as String?;
    final seats       = booking['seats_count'] ?? 1;
    final initials    = name.trim().split(' ')
        .where((p) => p.isNotEmpty).take(2)
        .map((p) => p[0].toUpperCase()).join();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: Colors.blue.shade200, shape: BoxShape.circle),
            child: Center(child: Text(initials,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (phone != '—') _phoneButtons(phone) else Text('—', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$seats мест',
                style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),

        if (address != null && address.isNotEmpty) ...[
          const SizedBox(height: 6),
          _addrRowWidget(Icons.location_on_outlined, Colors.blue.shade600,
            address + (entrance != null && entrance.isNotEmpty ? ', подъезд $entrance' : '')),
        ] else ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.location_off_outlined, size: 13, color: Colors.orange[400]),
            const SizedBox(width: 4),
            Text('Адрес подачи не указан',
                style: TextStyle(color: Colors.orange[700], fontSize: 12)),
          ]),
        ],

        for (final extra in extraPickups) ...[
          const SizedBox(height: 3),
          _addrRowWidget(Icons.add_location_alt_outlined, Colors.blue.shade400, _addrLine(extra)),
        ],

        if (destAddr != null && destAddr.isNotEmpty) ...[
          const SizedBox(height: 5),
          _addrRowWidget(Icons.flag_outlined, Colors.green.shade700,
            destAddr + (destEntrance != null && destEntrance.isNotEmpty ? ', подъезд $destEntrance' : '')),
        ],

        for (final extra in extraDests) ...[
          const SizedBox(height: 3),
          _addrRowWidget(Icons.flag_circle_outlined, Colors.green.shade400, _addrLine(extra)),
        ],

        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.comment_outlined, size: 13, color: Colors.amber[700]),
            const SizedBox(width: 4),
            Expanded(child: Text(comment,
                style: TextStyle(color: Colors.amber[800], fontSize: 12))),
          ]),
        ],

      ]),
    );
  }

  Widget _addrRowWidget(IconData icon, Color color, String text) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 12))),
    ]);
}

// ─── ЭКРАН СОЗДАНИЯ ПОЕЗДКИ ───────────────────────────────────────────────────

class _CreateTripScreen extends StatefulWidget {
  final String? Function() getToken;
  final List<dynamic> routes;
  const _CreateTripScreen({required this.getToken, required this.routes});

  @override
  State<_CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<_CreateTripScreen> {
  int? _routeId;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  final _seatsCtrl = TextEditingController(text: '4');
  final _priceCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _seatsCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit() async {
    if (_routeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите маршрут')));
      return;
    }
    final seats = int.tryParse(_seatsCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
    if (seats < 1 || price < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните места и цену')));
      return;
    }

    setState(() => _saving = true);
    final dep = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final token = widget.getToken();

    try {
      await Dio().post(
        '$kApiBase/trips/',
        queryParameters: {
          'route_id': _routeId,
          'departure_time': dep.toIso8601String(),
          'seats_total': seats,
          'price_per_seat': price,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Поездка создана!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['detail'] ?? 'Ошибка'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Новая поездка', style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: const AppBarOrnament(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _label('Маршрут'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                hint: const Text('Выберите маршрут'),
                value: _routeId,
                items: widget.routes.map<DropdownMenuItem<int>>((r) => DropdownMenuItem(
                  value: r['id'] as int,
                  child: Text('${r['city_from']} → ${r['city_to']}'),
                )).toList(),
                onChanged: (v) => setState(() => _routeId = v),
              ),
            ),
          ),

          const SizedBox(height: 16),
          _label('Дата и время отправления'),
          Row(children: [
            Expanded(
              child: _tapField(
                icon: Icons.calendar_today_outlined,
                text: '${_date.day.toString().padLeft(2,'0')}.${_date.month.toString().padLeft(2,'0')}.${_date.year}',
                onTap: _pickDate,
                primary: primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tapField(
                icon: Icons.access_time_outlined,
                text: '${_time.hour.toString().padLeft(2,'0')}:${_time.minute.toString().padLeft(2,'0')}',
                onTap: _pickTime,
                primary: primary,
              ),
            ),
          ]),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Мест в машине'),
              TextField(
                controller: _seatsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.event_seat_outlined),
                  hintText: '4',
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Цена за место (₸)'),
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.payments_outlined),
                  hintText: '3500',
                ),
              ),
            ])),
          ]),

          const SizedBox(height: 32),
          GestureDetector(
            onTap: _saving ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _saving ? null : kGradient,
                color: _saving ? Colors.grey[300] : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Создать поездку',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _tapField({required IconData icon, required String text, required VoidCallback onTap, required Color primary}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─── ТАБ 4: БАЛАНС ВОДИТЕЛЯ ──────────────────────────────────────────────────

class _BalanceTab extends StatefulWidget {
  final String? Function() getToken;
  const _BalanceTab({required this.getToken});

  @override
  State<_BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<_BalanceTab> {
  double _balance = 0;
  int _offerPrice = 50;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final token = widget.getToken();
    if (token == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      final res = await Dio().get(
        '$kApiBase/drivers/balance',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) setState(() {
        _balance    = (res.data['balance'] as num).toDouble();
        _offerPrice = (res.data['offer_price'] as num).toInt();
        _loading    = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showTopupDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.account_balance_wallet_outlined, color: kTeal),
          SizedBox(width: 10),
          Text('Пополнение баланса'),
        ]),
        content: const Text(
          'Для пополнения баланса свяжитесь с администратором:\n\n'
          '📞 Позвоните или напишите в поддержку — укажите сумму и ваш номер телефона.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(color: kNavy, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSendOffer = _balance >= _offerPrice;

    return RefreshIndicator(
      color: kNavy,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: kNavy))
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Карточка баланса ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: kGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: kNavy.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text('Текущий баланс', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
              const SizedBox(height: 16),
              Text(
                '${_balance.toStringAsFixed(0)} ₸',
                style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                canSendOffer
                    ? 'Можно отправить ${(_balance / _offerPrice).floor()} откликов'
                    : 'Недостаточно для отклика — пополните баланс',
                style: TextStyle(
                  color: canSendOffer ? Colors.white60 : Colors.orange[200],
                  fontSize: 13,
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Кнопка пополнить ──
          GestureDetector(
            onTap: _showTopupDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: kGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Пополнить баланс', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                )),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // ── Стоимость отклика ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.divC),
            ),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: context.iconBgC, borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.touch_app_outlined, color: context.iconC, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Стоимость одного отклика', style: TextStyle(
                  fontSize: 13, color: context.subC, fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 2),
                Text('$_offerPrice ₸', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: context.textC,
                )),
              ])),
              if (!canSendOffer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text('Нет средств', style: TextStyle(
                    color: Colors.orange[700], fontSize: 12, fontWeight: FontWeight.w600,
                  )),
                ),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Инфо-блок ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kTeal.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kTeal.withOpacity(0.18)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: kTeal, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'За каждый отклик на заявку пассажира списывается $_offerPrice ₸. '
                'Пополните баланс у администратора.',
                style: const TextStyle(color: kTeal, fontSize: 13, height: 1.5),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}
