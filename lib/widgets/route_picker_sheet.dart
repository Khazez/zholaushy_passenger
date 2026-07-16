import 'package:flutter/material.dart';
import '../theme.dart';

/// Bottom sheet выбора маршрута: поиск + список с иконкой направления
/// и ценой, текущий выбор подсвечен. Возвращает выбранный маршрут или
/// null, если закрыли без выбора.
Future<Map<String, dynamic>?> showRoutePickerSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> routes,
  Map<String, dynamic>? selected,
  String title = 'Выберите маршрут',
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RoutePickerSheet(routes: routes, selected: selected, title: title),
  );
}

class _RoutePickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> routes;
  final Map<String, dynamic>? selected;
  final String title;
  const _RoutePickerSheet({required this.routes, required this.selected, required this.title});

  @override
  State<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends State<_RoutePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.routes
        : widget.routes.where((r) {
            final label = '${r['city_from']} ${r['city_to']}'.toLowerCase();
            return label.contains(q);
          }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardC,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4, decoration: BoxDecoration(
              color: context.subC.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(99),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
              child: Row(children: [
                Expanded(child: Text(widget.title, style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: context.textC,
                ))),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: context.subC),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Container(
                decoration: BoxDecoration(color: context.bgC, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Icon(Icons.search_rounded, size: 18, color: context.subC),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(fontSize: 13.5, color: context.textC),
                      decoration: InputDecoration(
                        hintText: 'Найти маршрут',
                        hintStyle: TextStyle(fontSize: 13, color: context.subC.withValues(alpha: 0.7)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Divider(height: 1, color: context.divC),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text('Ничего не найдено', style: TextStyle(color: context.subC, fontSize: 13)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final r = filtered[i];
                        final isSel = widget.selected != null && widget.selected!['id'] == r['id'];
                        final price = r['current_price'];
                        return InkWell(
                          onTap: () => Navigator.pop(context, r),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: isSel ? 8 : 0, vertical: isSel ? 0 : 0),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? kTeal.withValues(alpha: 0.1) : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const SizedBox(width: 8),
                              Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(color: context.bgC, borderRadius: BorderRadius.circular(9)),
                                child: Icon(Icons.arrow_forward_rounded, size: 15, color: kTeal),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('${r['city_from']} → ${r['city_to']}', style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textC,
                                )),
                              ),
                              if (price != null)
                                Text('${(price as num).toStringAsFixed(0)} ₸', style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700,
                                  color: isSel ? kTeal : context.subC,
                                )),
                              if (isSel) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle_rounded, size: 18, color: kTeal),
                              ],
                              const SizedBox(width: 8),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }
}
