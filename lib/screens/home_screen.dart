import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../local_store.dart';
import '../url_helper.dart';
import 'profile_screen.dart';
import 'info_screens.dart';
import '../config.dart';
import '../theme.dart';
import '../app_state.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/account_drawer.dart';
import '../widgets/route_picker_sheet.dart';
import '../widgets/date_time_sheet.dart';

// Кнопки "Позвонить" и "WhatsApp" для номера телефона
Widget _phoneButtons(String phone, Color primary, {bool compact = false}) {
  final btn = OutlinedButton.icon(
    onPressed: () => openUrl('tel:$phone'),
    icon: Icon(Icons.phone_outlined, size: compact ? 14 : 16),
    label: Text('Позвонить', style: TextStyle(fontSize: compact ? 12 : 13)),
    style: OutlinedButton.styleFrom(
      foregroundColor: primary,
      side: BorderSide(color: primary.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
    ),
  );
  return compact ? btn : SizedBox(width: double.infinity, child: btn);
}

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _routes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final res = await Dio().get('$kApiBase/routes/');
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

  String? _getToken() => LocalStore.getString('token');

  void _logout() {
    LocalStore.remove('token');
    LocalStore.remove('mode');
    LocalStore.setString('theme', 'light');
    AppState.themeNotifier.value = ThemeMode.light;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgC,
      endDrawer: AccountDrawer(
        name: LocalStore.getString('name') ?? 'Пассажир',
        role: 'Пассажир',
        onProfile: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
        onSupport: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
        onSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        onAbout: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
        onLogout: _logout,
      ),
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        flexibleSpace: const AppBarOrnament(),
        title: const Text('ZHOLAUSHY', style: TextStyle(
          fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3,
        )),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            tooltip: 'История поездок',
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            tooltip: 'Профиль',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.directions_car_outlined, size: 20), text: 'Поездки'),
            Tab(icon: Icon(Icons.people_alt_outlined, size: 20), text: 'Попутки'),
          ],
        ),
      ),
      body: BodyOrnament(
        child: TabBarView(
          controller: _tabController,
          children: [
            _TripsTab(getToken: _getToken, routes: _routes),
            _PoputkaTab(getToken: _getToken, routes: _routes),
          ],
        ),
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
  Map<int, int> _offerCounts = {};
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
        '$kApiBase/trip-requests/my',
        options: Options(headers: headers),
      ).timeout(const Duration(seconds: 6));
      final data = res.data;
      final all = data is List ? data : (data['data'] ?? []);
      final ratedIds = (LocalStore.getString('rated_trips') ?? '')
          .split(',').where((s) => s.isNotEmpty)
          .map(int.tryParse).whereType<int>().toSet();
      _requests = all.where((r) {
        if (r['status'] == 'open') return true;
        if (r['status'] == 'accepted') {
          final ts = r['trip_status'] as String?;
          if (ts == 'cancelled') return false;
          if (ts == 'completed') {
            final tripId = r['trip_id'] as int?;
            return tripId != null && !ratedIds.contains(tripId);
          }
          return true;
        }
        return false;
      }).toList();
    } catch (_) {}

    // Загружаем количество офферов для каждой open-заявки параллельно
    final pendingIds = _requests
        .where((r) => r['status'] == 'open')
        .map((r) => r['id'] as int)
        .toList();
    if (pendingIds.isNotEmpty) {
      final entries = await Future.wait(
        pendingIds.map((id) async {
          try {
            final r = await dio.get(
              '$kApiBase/trip-requests/$id/offers',
              options: Options(headers: headers),
            ).timeout(const Duration(seconds: 5));
            return MapEntry(id, r.data is List ? (r.data as List).length : 0);
          } catch (_) {
            return MapEntry(id, 0);
          }
        }),
      );
      _offerCounts = Map.fromEntries(entries);
    } else {
      _offerCounts = {};
    }

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
    final hasContent = _requests.isNotEmpty;

    return Column(
      children: [
        Container(
          color: context.cardC,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: GestureDetector(
            onTap: () => _showCreateRequest(context),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: kGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: kNavy.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text('Создать заявку', style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                  )),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: context.bgC),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : !hasContent
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88, height: 88,
                            decoration: BoxDecoration(
                              gradient: kGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: kNavy.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Icon(Icons.directions_car_rounded, size: 44, color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          Text('Нет активных поездок',
                              style: TextStyle(color: context.textC, fontWeight: FontWeight.w700, fontSize: 17)),
                          const SizedBox(height: 8),
                          Text('Создайте заявку — водители предложат цену',
                              style: TextStyle(color: context.subC, fontSize: 13)),
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
                              getToken: widget.getToken,
                            ),

                          // Ожидающие заявки — маленькие
                          if (pendingRequests.isNotEmpty) ...[
                            if (acceptedRequests.isNotEmpty)
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
                                offerCount: _offerCounts[r['id'] as int] ?? 0,
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
class _AcceptedRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final String routeName;
  final VoidCallback onRefresh;
  final String? Function() getToken;
  const _AcceptedRequestCard({
    required this.request,
    required this.routeName,
    required this.onRefresh,
    required this.getToken,
  });

  @override
  State<_AcceptedRequestCard> createState() => _AcceptedRequestCardState();
}

class _AcceptedRequestCardState extends State<_AcceptedRequestCard> {
  bool _rated = false;

  void _markRated() {
    final tripId = widget.request['trip_id'] as int?;
    if (tripId != null) {
      final existing = LocalStore.getString('rated_trips') ?? '';
      LocalStore.setString('rated_trips',
          existing.isEmpty ? '$tripId' : '$existing,$tripId');
    }
    setState(() => _rated = true);
    widget.onRefresh();
  }

  Future<void> _showRatingDialog() async {
    int selectedScore = 0;
    final commentCtrl = TextEditingController();
    final driverName = widget.request['driver_name'] ?? 'водителя';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Оцените $driverName'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Как прошла поездка?', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
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
                      color: Colors.amber,
                      size: 44,
                    ),
                  ),
                );
              }),
            ),
            if (selectedScore > 0) ...[
              const SizedBox(height: 8),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена')),
            ElevatedButton(
              onPressed: selectedScore == 0
                  ? null
                  : () async {
                      final token = widget.getToken();
                      final comment = commentCtrl.text.trim();
                      try {
                        await Dio().post(
                          '$kApiBase/ratings/',
                          data: {
                            'trip_id': widget.request['trip_id'],
                            'to_user_id': widget.request['driver_user_id'],
                            'score': selectedScore,
                            if (comment.isNotEmpty) 'comment': comment,
                          },
                          options: Options(
                            headers: {'Authorization': 'Bearer $token'},
                            contentType: 'application/json',
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _markRated();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Спасибо за оценку!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } on DioException catch (e) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (e.response?.statusCode == 400) {
                          _markRated();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.response?.data?['detail'] ?? 'Ошибка'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
              ),
              child: Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final date = request['departure_date'] != null ? DateTime.tryParse(request['departure_date']) : null;
    final isDeparted = request['is_departed'] == true;
    final isArrived  = request['is_arrived']  == true;
    final canRate = !_rated &&
        request['trip_status'] == 'completed' &&
        request['trip_id'] != null &&
        request['driver_user_id'] != null;

    // Шапка меняется в зависимости от статуса водителя
    final (headerGradient, headerIcon, headerText) = isArrived
        ? (const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF8F00)]),
           Icons.location_on_rounded, 'Водитель подъехал · выходите!')
        : isDeparted
        ? (const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
           Icons.directions_car_rounded, 'Водитель выехал · едет к вам')
        : (kGradient, Icons.check_rounded, 'Водитель найден!');

    return GestureDetector(
      onTap: () => context.push('/active-trip', extra: Map<String, dynamic>.from(widget.request)..['route_name'] = widget.routeName),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cardC,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kTeal.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: kNavy.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Шапка — статус водителя
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(headerIcon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Text(headerText, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14,
              )),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
            ]),
          ),

          // Тело карточки
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(widget.routeName, style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17, color: context.textC,
                )),

                const SizedBox(height: 8),

                Row(children: [
                  if (date != null) ...[
                    Icon(Icons.calendar_today_outlined, size: 14, color: context.subC),
                    const SizedBox(width: 5),
                    Text(
                      '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}  '
                      '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}',
                      style: TextStyle(color: context.subC, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.event_seat_outlined, size: 14, color: context.subC),
                  const SizedBox(width: 5),
                  Text('${request['seats_needed']} мест', style: TextStyle(color: context.subC, fontSize: 13)),
                ]),

                if (request['driver_name'] != null || request['driver_phone'] != null) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, color: context.bgC),
                  const SizedBox(height: 14),

                  // Водитель
                  Row(children: [
                    AvatarView(
                      avatarUrl: request['driver_avatar_url'] as String?,
                      initials: ((request['driver_name'] as String?)?.trim().isNotEmpty == true
                          ? (request['driver_name'] as String).trim()[0] : '?').toUpperCase(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (request['driver_name'] != null)
                          Text(request['driver_name'],
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.textC)),
                        Text('Водитель', style: TextStyle(color: context.subC, fontSize: 12)),
                      ]),
                    ),
                  ]),

                  if (request['driver_phone'] != null) ...[
                    const SizedBox(height: 10),
                    _phoneButtons(request['driver_phone'] as String, kNavy),
                  ],

                  if (request['car_brand'] != null || request['car_number'] != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.bgC,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDE3F0)),
                      ),
                      child: Row(children: [
                        Icon(Icons.directions_car_outlined, size: 16, color: kTeal),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          [
                            if (request['car_brand'] != null) request['car_brand'],
                            if (request['car_model'] != null) request['car_model'],
                            if (request['car_year'] != null) '${request['car_year']}',
                            if (request['car_color'] != null) request['car_color'],
                          ].join(' '),
                          style: TextStyle(fontSize: 13, color: context.textC, fontWeight: FontWeight.w500),
                        )),
                        if (request['car_number'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kNavy,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(request['car_number'],
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold,
                                  letterSpacing: 1, color: Colors.white,
                                )),
                          ),
                      ]),
                    ),
                  ],
                ],

                if (canRate) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showRatingDialog,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF57F17), Color(0xFFFFCA28)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Оценить поездку', style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _markRated,
                      child: Text('Позже', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    )); // GestureDetector
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
  final int offerCount;
  const _PendingRequestCard({required this.request, required this.routeName, this.onRefresh, this.offerCount = 0});

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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.cardC,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: offerCount > 0 ? kTeal.withOpacity(0.5) : kNavy.withOpacity(0.12),
          ),
          boxShadow: [
            BoxShadow(color: kNavy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: offerCount > 0 ? kTeal.withOpacity(0.1) : kBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  offerCount > 0 ? Icons.notifications_active_outlined : Icons.schedule_rounded,
                  size: 16,
                  color: offerCount > 0 ? kTeal : kSubtext,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(routeName,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.textC)),
              ),
              if (offerCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: kGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$offerCount ${offerCount == 1 ? 'отклик' : 'откликов'}',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.bgC,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDDE3F0)),
                  ),
                  child: Text('Ожидает',
                      style: TextStyle(color: context.subC, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
            ]),
            const SizedBox(height: 8),
            if (date != null)
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: context.subC),
                const SizedBox(width: 5),
                Text(
                  '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}  '
                  '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}',
                  style: TextStyle(color: context.subC, fontSize: 12),
                ),
              ]),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              _chip(context, Icons.event_seat_outlined, '${request['seats_needed'] ?? 1} мест'),
              _chip(context, Icons.payments_outlined, paymentLabel),
              if (request['pickup_address'] != null)
                _chip(context, Icons.location_on_outlined, request['pickup_address']),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                offerCount > 0 ? Icons.touch_app_rounded : Icons.info_outline_rounded,
                size: 12,
                color: offerCount > 0 ? kTeal : kSubtext,
              ),
              const SizedBox(width: 4),
              Text(
                offerCount > 0 ? 'Нажмите, чтобы принять водителя' : 'Нажмите, чтобы увидеть предложения',
                style: TextStyle(
                  color: offerCount > 0 ? kTeal : kSubtext,
                  fontSize: 11,
                  fontWeight: offerCount > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: context.subC),
    const SizedBox(width: 3),
    Text(text, style: TextStyle(color: context.subC, fontSize: 12)),
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
  String? _error;
  int? _accepting;
  int? _declining;

  String? _getToken() => LocalStore.getString('token');

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() { _loading = true; _error = null; });
    final token = _getToken();
    if (token == null) { setState(() => _loading = false); return; }
    try {
      final res = await Dio().get(
        '$kApiBase/trip-requests/${widget.request['id']}/offers',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 10));
      final data = res.data;
      setState(() {
        _offers = data is List ? data : (data is Map ? (data['data'] ?? []) : []);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _loading = false;
        _error = e.response?.data?['detail'] ?? 'Ошибка ${e.response?.statusCode ?? "сети"}';
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _accept(int offerId) async {
    setState(() => _accepting = offerId);
    final token = _getToken();
    try {
      await Dio().post(
        '$kApiBase/trip-requests/${widget.request['id']}/accept/$offerId',
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

  Future<void> _decline(int offerId) async {
    setState(() => _declining = offerId);
    final token = _getToken();
    try {
      await Dio().delete(
        '$kApiBase/trip-requests/${widget.request['id']}/offers/$offerId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 8));
      setState(() => _offers.removeWhere((o) => o['id'] == offerId));
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['detail'] ?? 'Ошибка'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _declining = null);
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
    final date = widget.request['departure_date'] != null
        ? DateTime.tryParse(widget.request['departure_date'])
        : null;
    final payment = widget.request['payment_type'] ?? 'cash';
    final paymentLabel = payment == 'card' ? 'Карта' : payment == 'kaspi' ? 'Kaspi' : 'Наличные';

    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        flexibleSpace: const AppBarOrnament(),
        title: Text('Предложения водителей',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined),
            tooltip: 'Редактировать заявку',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _loadOffers,
          ),
        ],
      ),
      body: Column(children: [

        // ── Шапка с деталями заявки ──
        Container(
          color: context.cardC,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.routeName,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: context.textC)),
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

        Divider(height: 1, color: context.bgC),

        // ── Список офферов ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kTeal))
              : RefreshIndicator(
                  color: kTeal,
                  onRefresh: _loadOffers,
                  child: _error != null
                      ? ListView(children: [_errorState(_error!)])
                      : _offers.isEmpty
                      ? ListView(children: [_emptyState()])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _offers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _OfferCard(
                            offer: _offers[i],
                            seatsNeeded: widget.request['seats_needed'] ?? 1,
                            isAccepting: _accepting == _offers[i]['id'],
                            isDeclining: _declining == _offers[i]['id'],
                            onAccept: () => _accept(_offers[i]['id']),
                            onDecline: () => _decline(_offers[i]['id']),
                          ),
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _tag(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: kTeal),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(color: context.textC, fontSize: 13)),
  ]);

  Widget _errorState(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline_rounded, size: 56, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text('Не удалось загрузить',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.textC)),
        const SizedBox(height: 8),
        Text(msg, style: TextStyle(color: context.subC, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _loadOffers,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            decoration: BoxDecoration(
              gradient: kGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('Повторить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: context.bgC,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDDE3F0), width: 2),
        ),
        child: Icon(Icons.hourglass_empty_rounded, size: 40, color: context.subC),
      ),
      const SizedBox(height: 20),
      Text('Ждём водителей',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textC)),
      const SizedBox(height: 8),
      Text('Водители видят вашу заявку и скоро откликнутся',
          style: TextStyle(color: context.subC, fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: _loadOffers,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          decoration: BoxDecoration(
            gradient: kGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: kNavy.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Обновить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    ]),
  );
}

// Карточка одного предложения от водителя
class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final int seatsNeeded;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OfferCard({
    required this.offer,
    required this.seatsNeeded,
    required this.isAccepting,
    required this.isDeclining,
    required this.onAccept,
    required this.onDecline,
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
        color: context.cardC,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE3F0)),
        boxShadow: [
          BoxShadow(color: kNavy.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Водитель
        Row(children: [
          AvatarView(
            size: 44,
            avatarUrl: offer['driver_avatar_url'] as String?,
            initials: ((offer['driver_name'] as String?)?.trim().isNotEmpty == true
                ? (offer['driver_name'] as String).trim()[0] : '?').toUpperCase(),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(offer['driver_name'] ?? '—',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.textC)),
            const SizedBox(height: 2),
            Row(children: [
              if (offer['driver_avg_rating'] != null) ...[
                Icon(Icons.star_rounded, size: 13, color: Colors.amber[600]),
                const SizedBox(width: 2),
                Text('${offer['driver_avg_rating']}',
                    style: TextStyle(fontSize: 12, color: Colors.amber[800], fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
              ],
              if (offer['driver_phone'] != null)
                _phoneButtons(offer['driver_phone'] as String, kNavy, compact: true),
            ]),
          ])),
          // Цена за всё
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$totalPrice ₸',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kNavy)),
            if (seatsNeeded > 1)
              Text('$pricePerSeat ₸/место',
                  style: TextStyle(color: context.subC, fontSize: 11)),
          ]),
        ]),

        // Машина
        if (offer['car_brand'] != null || offer['car_number'] != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.bgC,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE3F0)),
            ),
            child: Row(children: [
              Icon(Icons.directions_car_outlined, size: 16, color: kTeal),
              const SizedBox(width: 8),
              Expanded(child: Text(
                [
                  if (offer['car_brand'] != null) offer['car_brand'],
                  if (offer['car_model'] != null) offer['car_model'],
                  if (offer['car_year'] != null) '${offer['car_year']}',
                  if (offer['car_color'] != null) offer['car_color'],
                ].join(' '),
                style: TextStyle(fontSize: 13, color: context.textC, fontWeight: FontWeight.w500),
              )),
              if (offer['car_number'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kNavy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(offer['car_number'],
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white,
                      )),
                ),
            ]),
          ),
        ],

        if (depTime != null) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: context.bgC),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.access_time_outlined, size: 15, color: context.subC),
            const SizedBox(width: 6),
            Text(
              'Отправление: ${depTime.day.toString().padLeft(2,'0')}.${depTime.month.toString().padLeft(2,'0')}  '
              '${depTime.hour.toString().padLeft(2,'0')}:${depTime.minute.toString().padLeft(2,'0')}',
              style: TextStyle(color: context.subC, fontSize: 13),
            ),
            const Spacer(),
            Icon(Icons.event_seat_outlined, size: 15, color: context.subC),
            const SizedBox(width: 4),
            Text('${offer['seats_available'] ?? '?'} св.',
                style: TextStyle(color: context.subC, fontSize: 13)),
          ]),
        ],

        const SizedBox(height: 14),

        // Кнопки принять / отклонить
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: (isAccepting || isDeclining) ? null : onDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[600],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: Size.zero,
              ),
              child: isDeclining
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[400]))
                  : Text('Отклонить', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: (isAccepting || isDeclining) ? null : onAccept,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 46,
                decoration: BoxDecoration(
                  gradient: (isAccepting || isDeclining) ? null : kGradient,
                  color: (isAccepting || isDeclining) ? const Color(0xFFDDE3F0) : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: (isAccepting || isDeclining) ? null : [
                    BoxShadow(color: kNavy.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: isAccepting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Принять водителя',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ),
        ]),
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
        '$kApiBase/bookings/',
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
    final price     = (widget.trip['price_per_seat'] as num?)?.toDouble() ?? 0;
    final available = widget.trip['seats_available'] as int? ?? 0;
    final dep       = widget.trip['departure_time'] != null
        ? DateTime.tryParse(widget.trip['departure_time']) : null;

    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        flexibleSpace: const AppBarOrnament(),
        title: Text('Бронирование', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Сводка поездки
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE3F0)),
              boxShadow: [BoxShadow(color: kNavy.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.routeName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.textC)),
              if (dep != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${dep.day.toString().padLeft(2,'0')}.${dep.month.toString().padLeft(2,'0')}.${dep.year}  '
                  '${dep.hour.toString().padLeft(2,'0')}:${dep.minute.toString().padLeft(2,'0')}',
                  style: TextStyle(color: context.subC),
                ),
              ],
              const SizedBox(height: 6),
              Text('${price.toStringAsFixed(0)} ₸ за место',
                  style: TextStyle(color: kTeal, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),

          const SizedBox(height: 20),
          _sectionTitle('Количество мест'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE3F0)),
            ),
            child: Row(children: [
              IconButton(
                onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                icon: Icon(Icons.remove_circle_outline),
                color: kNavy,
              ),
              Expanded(child: Column(children: [
                Text('$_seats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textC)),
                Text('${(price * _seats).toStringAsFixed(0)} ₸ итого',
                    style: TextStyle(color: kTeal, fontWeight: FontWeight.w600)),
              ])),
              IconButton(
                onPressed: _seats < available ? () => setState(() => _seats++) : null,
                icon: Icon(Icons.add_circle_outline),
                color: kNavy,
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
                icon: Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 6),
            _field(_extraPairs[i].entrance, 'Подъезд (необязательно)', Icons.door_front_door_outlined),
          ],

          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _addExtraPickup,
            icon: Icon(Icons.add_location_alt_outlined),
            label: Text('Добавить адрес подачи'),
            style: TextButton.styleFrom(
              foregroundColor: kTeal,
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
                icon: Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 6),
            _field(_extraDestPairs[i].entrance, 'Подъезд (необязательно)', Icons.door_front_door_outlined),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addExtraDest,
            icon: Icon(Icons.flag_circle_outlined),
            label: Text('Добавить точку назначения'),
            style: TextButton.styleFrom(
              foregroundColor: kTeal,
              padding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 20),
          Row(children: [
            _sectionTitle('Заказ для другого человека'),
            const Spacer(),
            Switch(value: _forOther, onChanged: (v) => setState(() => _forOther = v), activeColor: kTeal),
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
          GestureDetector(
            onTap: _saving ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              decoration: BoxDecoration(
                gradient: _saving ? null : kGradient,
                color: _saving ? const Color(0xFFDDE3F0) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _saving ? null : [
                  BoxShadow(color: kNavy.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        'Забронировать · ${(price * _seats).toStringAsFixed(0)} ₸',
                        style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700,
                          fontSize: 16, letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Отменить заявку?'),
        content: Text('Заявка будет отменена и удалена из активных.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Нет')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text('Да, отменить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final token = LocalStore.getString('token');
    if (token == null) return;
    try {
      await Dio().delete(
        '$kApiBase/trip-requests/${widget.request['id']}',
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
    final token = LocalStore.getString('token');
    if (token == null) return;
    setState(() => _loading = true);

    final departure = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    try {
      await Dio().patch(
        '$kApiBase/trip-requests/${widget.request['id']}',
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
      fillColor: context.cardC,
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.8, color: Colors.grey[500])),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        flexibleSpace: const AppBarOrnament(),
        title: Text('Изменить заявку', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _cancel,
            child: Text('Отменить заявку', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
              color: context.cardC,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE3F0)),
            ),
            child: Row(children: [
              Icon(Icons.route_outlined, color: kTeal),
              const SizedBox(width: 12),
              Text(widget.routeName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textC)),
            ]),
          ),

          // Дата и время
          _section('Дата и время'),
          DateTimeField(
            date: _selectedDate,
            time: _selectedTime,
            onDateChanged: (d) => setState(() => _selectedDate = d),
            onTimeChanged: (t) => setState(() => _selectedTime = t),
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
                icon: Icon(Icons.remove_circle_outline, color: Colors.red),
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
            icon: Icon(Icons.add_location_alt_outlined),
            label: Text('Добавить адрес подачи'),
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
                icon: Icon(Icons.remove_circle_outline, color: Colors.red),
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
            icon: Icon(Icons.flag_circle_outlined),
            label: Text('Добавить точку назначения'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),

          // Места
          _section('Количество мест'),
          _inputField(controller: _seatsCtrl, label: 'Мест',
              icon: Icons.event_seat_outlined, keyboard: TextInputType.number),

          // Оплата
          _section('Способ оплаты'),
          Container(
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE3F0)),
            ),
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
                        color: _paymentType == entry.$1 ? kNavy : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(entry.$3, size: 20,
                            color: _paymentType == entry.$1 ? Colors.white : kSubtext),
                        const SizedBox(height: 4),
                        Text(entry.$2, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _paymentType == entry.$1 ? Colors.white : kSubtext,
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
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE3F0)),
            ),
            child: Column(children: [
              RadioListTile<bool>(
                value: false, groupValue: _forOther,
                onChanged: (v) => setState(() => _forOther = false),
                title: Text('Для себя'), activeColor: kTeal,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              const Divider(height: 1, indent: 16),
              RadioListTile<bool>(
                value: true, groupValue: _forOther,
                onChanged: (v) => setState(() => _forOther = true),
                title: Text('Для другого человека'), activeColor: kTeal,
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

          GestureDetector(
            onTap: _loading ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              decoration: BoxDecoration(
                gradient: _loading ? null : kGradient,
                color: _loading ? const Color(0xFFDDE3F0) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _loading ? null : [
                  BoxShadow(color: kNavy.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Сохранить изменения', style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                      )),
              ),
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
        '$kApiBase/trip-requests/',
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
          LocalStore.remove('token');
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
        fillColor: context.cardC,
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
    final canSubmit = _selectedRoute != null && _selectedDate != null && _selectedTime != null && !_loading;

    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        flexibleSpace: const AppBarOrnament(),
        title: Text('Новая заявка', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [

          // ── МАРШРУТ ──
          _section('Маршрут'),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final picked = await showRoutePickerSheet(context, routes: widget.routes, selected: _selectedRoute);
              if (picked != null) setState(() => _selectedRoute = picked);
            },
            child: Container(
              decoration: BoxDecoration(
                color: context.cardC,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDE3F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                const Icon(Icons.route_outlined, color: kTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Откуда → Куда', style: TextStyle(fontSize: 11, color: context.subC)),
                    const SizedBox(height: 2),
                    Text(
                      _selectedRoute != null
                          ? '${_selectedRoute!['city_from']} → ${_selectedRoute!['city_to']}'
                          : 'Выберите маршрут',
                      style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700,
                        color: _selectedRoute != null ? context.textC : context.subC,
                      ),
                    ),
                  ]),
                ),
                Icon(Icons.expand_more_rounded, color: context.subC),
              ]),
            ),
          ),

          // ── ДАТА И ВРЕМЯ ──
          _section('Дата и время'),
          DateTimeField(
            date: _selectedDate,
            time: _selectedTime,
            onDateChanged: (d) => setState(() => _selectedDate = d),
            onTimeChanged: (t) => setState(() => _selectedTime = t),
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
                icon: Icon(Icons.remove_circle_outline, color: Colors.red),
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
            icon: Icon(Icons.add_location_alt_outlined),
            label: Text('Добавить адрес подачи'),
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
                icon: Icon(Icons.remove_circle_outline, color: Colors.red),
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
            icon: Icon(Icons.flag_circle_outlined),
            label: Text('Добавить точку назначения'),
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
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE3F0)),
            ),
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
                        color: _paymentType == entry.$1 ? kNavy : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(entry.$3,
                            size: 20,
                            color: _paymentType == entry.$1 ? Colors.white : kSubtext),
                        const SizedBox(height: 4),
                        Text(entry.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _paymentType == entry.$1 ? Colors.white : kSubtext,
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
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE3F0)),
            ),
            child: Column(children: [
              RadioListTile<bool>(
                value: false,
                groupValue: _forOther,
                onChanged: (v) => setState(() => _forOther = false),
                title: Text('Для себя'),
                activeColor: kTeal,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              const Divider(height: 1, indent: 16),
              RadioListTile<bool>(
                value: true,
                groupValue: _forOther,
                onChanged: (v) => setState(() => _forOther = true),
                title: Text('Для другого человека'),
                activeColor: kTeal,
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
          GestureDetector(
            onTap: canSubmit ? _submit : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              decoration: BoxDecoration(
                gradient: canSubmit ? kGradient : null,
                color: canSubmit ? null : const Color(0xFFDDE3F0),
                borderRadius: BorderRadius.circular(16),
                boxShadow: canSubmit ? [
                  BoxShadow(color: kNavy.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                ] : null,
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Отправить заявку', style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                      )),
              ),
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
        '$kApiBase/trips/',
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
    final canSearch = _selectedRoute != null && !_loading;
    return Column(
      children: [
        Container(
          color: context.cardC,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final picked = await showRoutePickerSheet(
                      context, routes: widget.routes, selected: _selectedRoute, title: 'Куда едете?',
                    );
                    if (picked != null) {
                      setState(() { _selectedRoute = picked; _searched = false; _trips = []; });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.bgC,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDDE3F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      const Icon(Icons.search_rounded, color: kTeal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedRoute != null
                              ? '${_selectedRoute!['city_from']} → ${_selectedRoute!['city_to']}'
                              : 'Выберите маршрут',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: _selectedRoute != null ? context.textC : context.subC,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: canSearch ? _search : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 74, height: 52,
                  decoration: BoxDecoration(
                    gradient: canSearch ? kGradient : null,
                    color: canSearch ? null : const Color(0xFFDDE3F0),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: canSearch ? [
                      BoxShadow(color: kNavy.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                    ] : null,
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Найти',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.bgC),
        Expanded(
          child: !_searched
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: context.bgC,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFDDE3F0), width: 2),
                        ),
                        child: Icon(Icons.search_rounded, size: 40, color: context.subC),
                      ),
                      const SizedBox(height: 20),
                      Text('Выберите маршрут',
                          style: TextStyle(fontSize: 17, color: context.textC, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('Найдём доступные поездки',
                          style: TextStyle(color: context.subC, fontSize: 13)),
                    ],
                  ),
                )
              : _trips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: context.bgC,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFDDE3F0), width: 2),
                            ),
                            child: Icon(Icons.search_off_rounded, size: 40, color: context.subC),
                          ),
                          const SizedBox(height: 20),
                          Text('Поездок по этому маршруту нет',
                              style: TextStyle(color: context.textC, fontWeight: FontWeight.w700, fontSize: 17)),
                          const SizedBox(height: 8),
                          Text('Создайте заявку во вкладке "Поездки"',
                              style: TextStyle(color: context.subC, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: kTeal,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardC,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE3F0)),
        boxShadow: [
          BoxShadow(color: kNavy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(gradient: kGradient, shape: BoxShape.circle),
              child: Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(routeName, style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15, color: context.textC,
                )),
                if (date != null)
                  Text(
                    '${date.day}.${date.month}.${date.year} в ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: context.subC, fontSize: 13),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            Text('${trip['price_per_seat']} ₸',
                style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17, color: kNavy,
                )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.event_seat_outlined, size: 15, color: context.subC),
            const SizedBox(width: 4),
            Text('${trip['seats_available']} мест свободно',
                style: TextStyle(color: context.subC, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: () => _openBookingForm(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  gradient: kGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: kNavy.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text('Забронировать',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
