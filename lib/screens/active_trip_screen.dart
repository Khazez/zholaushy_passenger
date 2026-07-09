import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../local_store.dart';
import '../url_helper.dart';
import '../config.dart';
import '../theme.dart';

class ActiveTripScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const ActiveTripScreen({super.key, required this.request});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _data;
  Timer? _timer;
  bool _cancelling = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  String? get _token => LocalStore.getString('token');

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.request);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final res = await Dio().get(
        '$kApiBase/trip-requests/my',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final raw = res.data;
      final list = raw is List ? raw : (raw['data'] ?? []) as List;
      final updated = list.firstWhere(
        (r) => r['id'] == widget.request['id'],
        orElse: () => null,
      );
      if (updated != null && mounted) {
        setState(() => _data = Map<String, dynamic>.from(updated));
        // Авто-переход на главную когда поездка завершена или отменена
        final ts = updated['trip_status'] as String?;
        if (ts == 'completed' || ts == 'cancelled') {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/home');
        }
      }
    } catch (_) {}
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Отменить поездку?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Водитель получит уведомление об отмене.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да, отменить', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final bookingId = _data['booking_id'];
      final requestId = _data['id'];
      if (bookingId != null) {
        await Dio().delete(
          '$kApiBase/bookings/$bookingId',
          options: Options(headers: {'Authorization': 'Bearer $_token'}),
        );
      } else {
        await Dio().delete(
          '$kApiBase/trip-requests/$requestId',
          options: Options(headers: {'Authorization': 'Bearer $_token'}),
        );
      }
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['detail'] ?? 'Ошибка отмены'),
              backgroundColor: Colors.red),
        );
        setState(() => _cancelling = false);
      }
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tripStatus  = _data['trip_status']  as String? ?? 'active';
    final isDeparted  = _data['is_departed']  == true;
    final isArrived   = _data['is_arrived']   == true;
    final isCompleted = tripStatus == 'completed';
    final isCancelled = tripStatus == 'cancelled';
    final isActive    = !isCompleted && !isCancelled;

    final driverName  = _data['driver_name']  as String? ?? '?';
    final driverPhone = _data['driver_phone'] as String? ?? '';
    final carBrand    = _data['car_brand']    as String? ?? '';
    final carModel    = _data['car_model']    as String? ?? '';
    final carColor    = _data['car_color']    as String? ?? '';
    final carNumber   = _data['car_number']   as String? ?? '';
    final carYear     = _data['car_year']?.toString() ?? '';
    final routeName   = _data['route_name']   as String? ?? '';
    final agreedPrice = _data['agreed_price'];
    final pickupAddr  = _data['pickup_address']      as String? ?? '';
    final destAddr    = _data['destination_address'] as String? ?? '';

    return Scaffold(
      backgroundColor: context.bgC,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Активная поездка', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        flexibleSpace: const AppBarOrnament(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Статус-баннер ──
          _buildStatusBanner(tripStatus, isDeparted, isArrived),
          const SizedBox(height: 16),

          // ── Карточка водителя ──
          Container(
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: context.shadowC, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(children: [

              Row(children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(gradient: kGradient, shape: BoxShape.circle),
                  child: Center(child: Text(
                    _initials(driverName),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(driverName, style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: context.textC,
                  )),
                  if (carBrand.isNotEmpty || carModel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('$carBrand $carModel'.trim(), style: TextStyle(fontSize: 14, color: context.subC)),
                  ],
                  if (carColor.isNotEmpty || carYear.isNotEmpty)
                    Text(
                      [if (carColor.isNotEmpty) carColor, if (carYear.isNotEmpty) '$carYear г.'].join(' · '),
                      style: TextStyle(fontSize: 12, color: context.subC),
                    ),
                ])),
              ]),

              if (carNumber.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.bgC,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divC, width: 1.5),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.credit_card_outlined, size: 18, color: context.iconC),
                    const SizedBox(width: 10),
                    Text(carNumber, style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      letterSpacing: 3, color: context.textC,
                    )),
                  ]),
                ),
              ],

              if (driverPhone.isNotEmpty) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => openUrl('tel:$driverPhone'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: const BoxDecoration(
                      gradient: kGradient,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Позвонить водителю',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // ── Детали поездки ──
          Container(
            decoration: BoxDecoration(
              color: context.cardC,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: context.shadowC, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Детали поездки', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: context.textC,
              )),
              const SizedBox(height: 14),
              if (routeName.isNotEmpty)
                _DetailRow(icon: Icons.route_outlined, label: 'Маршрут', value: routeName),
              if (agreedPrice != null)
                _DetailRow(icon: Icons.payments_outlined, label: 'Стоимость',
                    value: '${(agreedPrice as num).toStringAsFixed(0)} ₸'),
              if (pickupAddr.isNotEmpty)
                _DetailRow(icon: Icons.location_on_outlined, label: 'Адрес подачи', value: pickupAddr),
              if (destAddr.isNotEmpty)
                _DetailRow(icon: Icons.flag_outlined, label: 'Назначение', value: destAddr),
            ]),
          ),

          const SizedBox(height: 24),

          if (isActive) ...[
            GestureDetector(
              onTap: _cancelling ? null : _cancelBooking,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.35)),
                ),
                child: Center(
                  child: _cancelling
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                      : const Text('Отменить поездку',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (isCancelled)
            _resultBanner(Colors.red, Icons.cancel_rounded, 'Поездка была отменена'),

          if (isCompleted)
            _resultBanner(Colors.green, Icons.check_circle_rounded, 'Поездка успешно завершена!'),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildStatusBanner(String tripStatus, bool isDeparted, bool isArrived) {
    if (tripStatus == 'completed') {
      return _bannerWidget(Colors.green, Icons.check_circle_rounded, 'Поездка завершена', showSpinner: false);
    }
    if (tripStatus == 'cancelled') {
      return _bannerWidget(Colors.red, Icons.cancel_rounded, 'Поездка отменена', showSpinner: false);
    }

    if (isArrived) {
      return ScaleTransition(
        scale: _pulse,
        child: _bannerWidget(
          Colors.orange[700]!,
          Icons.location_on_rounded,
          'Водитель подъехал · выходите!',
          showSpinner: false,
          bold: true,
        ),
      );
    }

    if (isDeparted) {
      return _bannerWidget(
        Colors.blue[700]!,
        Icons.directions_car_rounded,
        'Водитель выехал · едет к вам',
      );
    }

    return _bannerWidget(kTeal, Icons.access_time_rounded, 'Ожидайте · водитель скоро выедет');
  }

  Widget _bannerWidget(Color color, IconData icon, String text,
      {bool showSpinner = true, bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: color,
        ))),
        if (showSpinner)
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color)),
      ]),
    );
  }

  Widget _resultBanner(Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: context.iconBgC, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: context.iconC),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.subC, fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 14, color: context.textC, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }
}
