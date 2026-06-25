import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../config.dart';

class CarInfoScreen extends StatefulWidget {
  final bool isUpdate;
  const CarInfoScreen({super.key, this.isUpdate = false});

  @override
  State<CarInfoScreen> createState() => _CarInfoScreenState();
}

class _CarInfoScreenState extends State<CarInfoScreen> {
  final _brandCtrl  = TextEditingController();
  final _modelCtrl  = TextEditingController();
  final _yearCtrl   = TextEditingController();
  final _colorCtrl  = TextEditingController();
  final _numberCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isUpdate) _loadExisting();
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final token = html.window.localStorage['token'];
    if (token == null) return;
    try {
      final res = await Dio().get(
        '$kApiBase/drivers/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final d = res.data['data'];
      setState(() {
        _brandCtrl.text  = d['car_brand']  ?? '';
        _modelCtrl.text  = d['car_model']  ?? '';
        _yearCtrl.text   = (d['car_year']  ?? '').toString();
        _colorCtrl.text  = d['car_color']  ?? '';
        _numberCtrl.text = d['car_number'] ?? '';
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    final brand  = _brandCtrl.text.trim();
    final model  = _modelCtrl.text.trim();
    final yearS  = _yearCtrl.text.trim();
    final color  = _colorCtrl.text.trim();
    final number = _numberCtrl.text.trim();

    if (brand.isEmpty || model.isEmpty || yearS.isEmpty || color.isEmpty || number.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }
    final year = int.tryParse(yearS);
    if (year == null || year < 1990 || year > 2030) {
      setState(() => _error = 'Укажите корректный год (1990–2030)');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final token = html.window.localStorage['token'];
    if (token == null) { setState(() { _loading = false; _error = 'Нет токена'; }); return; }

    final params = 'car_brand=$brand&car_model=$model&car_year=$year&car_color=$color&car_number=$number';

    try {
      if (widget.isUpdate) {
        await Dio().patch(
          '$kApiBase/drivers/profile/vehicle?$params',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } else {
        await Dio().post(
          '$kApiBase/drivers/profile?$params',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
      if (mounted) context.go('/pending');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['detail'] ?? 'Ошибка сохранения');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: widget.isUpdate
          ? AppBar(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              title: const Text('Сменить автомобиль', style: TextStyle(fontWeight: FontWeight.bold)),
              elevation: 0,
            )
          : null,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              if (!widget.isUpdate) ...[
                Center(child: Column(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.directions_car_outlined, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 14),
                  const Text('Данные автомобиля', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Шаг 2 из 2 — укажите ваш автомобиль',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ])),
                const SizedBox(height: 32),
              ],

              _label('Марка'),
              const SizedBox(height: 6),
              TextField(
                controller: _brandCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Toyota, Hyundai, Kia...', prefixIcon: Icon(Icons.directions_car_outlined)),
              ),

              const SizedBox(height: 14),

              _label('Модель'),
              const SizedBox(height: 6),
              TextField(
                controller: _modelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Camry, Accent, Rio...', prefixIcon: Icon(Icons.commute_outlined)),
              ),

              const SizedBox(height: 14),

              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Год выпуска'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '2020', prefixIcon: Icon(Icons.calendar_today_outlined)),
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Цвет'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _colorCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Белый', prefixIcon: Icon(Icons.palette_outlined)),
                  ),
                ])),
              ]),

              const SizedBox(height: 14),

              _label('Госномер'),
              const SizedBox(height: 6),
              TextField(
                controller: _numberCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: '123 ABC 02', prefixIcon: Icon(Icons.pin_outlined)),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Отправить на проверку'),
              ),

              if (!widget.isUpdate) ...[
                const SizedBox(height: 12),
                Center(child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('← Назад', style: TextStyle(color: Colors.grey[600])),
                )),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
}
