import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../local_store.dart';
import '../config.dart';
import '../theme.dart';

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
    final token = LocalStore.getString('token');
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

    final token = LocalStore.getString('token');
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
    return Scaffold(
      backgroundColor: context.bgC,
      appBar: widget.isUpdate
          ? AppBar(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              title: const Text('Сменить автомобиль', style: TextStyle(fontWeight: FontWeight.bold)),
              elevation: 0,
              flexibleSpace: const AppBarOrnament(),
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
                    decoration: BoxDecoration(
                      gradient: kGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.directions_car_outlined, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 14),
                  Text('Данные автомобиля', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.textC)),
                  const SizedBox(height: 6),
                  Text('Шаг 2 из 2 — укажите ваш автомобиль',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ])),
                const SizedBox(height: 32),
              ],

              _label(context, 'Марка'),
              const SizedBox(height: 6),
              TextField(
                controller: _brandCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Toyota, Hyundai, Kia...', prefixIcon: Icon(Icons.directions_car_outlined)),
              ),

              const SizedBox(height: 14),

              _label(context, 'Модель'),
              const SizedBox(height: 6),
              TextField(
                controller: _modelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Camry, Accent, Rio...', prefixIcon: Icon(Icons.commute_outlined)),
              ),

              const SizedBox(height: 14),

              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label(context, 'Год выпуска'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '2020', prefixIcon: Icon(Icons.calendar_today_outlined)),
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label(context, 'Цвет'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _colorCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Белый', prefixIcon: Icon(Icons.palette_outlined)),
                  ),
                ])),
              ]),

              const SizedBox(height: 14),

              _label(context, 'Госномер'),
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

              GestureDetector(
                onTap: _loading ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _loading ? null : kGradient,
                    color: _loading ? Colors.grey[300] : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text(
                            'Отправить на проверку',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),

              if (!widget.isUpdate) ...[
                const SizedBox(height: 12),
                Center(child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('← Назад', style: TextStyle(color: context.subC)),
                )),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) =>
      Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textC));
}
