import 'package:flutter/material.dart';
import '../theme.dart';

class DateTimePick {
  final DateTime date;
  final TimeOfDay time;
  const DateTimePick(this.date, this.time);
}

const _months = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

/// Поле-триггер "Дата и время" — открывает [showDateTimeSheet] по тапу.
class DateTimeField extends StatelessWidget {
  final DateTime? date;
  final TimeOfDay? time;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const DateTimeField({
    super.key,
    required this.date,
    required this.time,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = date != null && time != null;
    final label = hasValue
        ? '${date!.day} ${_months[date!.month - 1]} · ${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
        : 'Выберите дату и время';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showDateTimeSheet(context, initialDate: date, initialTime: time);
        if (picked != null) {
          onDateChanged(picked.date);
          onTimeChanged(picked.time);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.cardC,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE3F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, color: kTeal, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Дата и время', style: TextStyle(fontSize: 11, color: context.subC)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w700,
                color: hasValue ? context.textC : context.subC,
              )),
            ]),
          ),
          Icon(Icons.expand_more_rounded, color: context.subC),
        ]),
      ),
    );
  }
}

const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Bottom sheet выбора даты и времени: карточки дней сверху, колёсико
/// часы/минуты снизу (24-часовой формат, без AM/PM).
Future<DateTimePick?> showDateTimeSheet(
  BuildContext context, {
  DateTime? initialDate,
  TimeOfDay? initialTime,
  String title = 'Когда поедете?',
  String subtitle = 'Заявку увидят водители, у которых поездка на эту дату и время.',
}) {
  return showModalBottomSheet<DateTimePick>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DateTimeSheet(
      initialDate: initialDate, initialTime: initialTime, title: title, subtitle: subtitle,
    ),
  );
}

class _DateTimeSheet extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final String title;
  final String subtitle;
  const _DateTimeSheet({this.initialDate, this.initialTime, required this.title, required this.subtitle});

  @override
  State<_DateTimeSheet> createState() => _DateTimeSheetState();
}

class _DateTimeSheetState extends State<_DateTimeSheet> {
  late final List<DateTime> _days;
  late DateTime _selectedDay;
  late int _hour;
  late int _minuteIndex; // индекс в шаге 5 минут: 0..11 → 00,05,...,55
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = List.generate(14, (i) => today.add(Duration(days: i)));

    final initDate = widget.initialDate ?? today.add(const Duration(days: 1));
    _selectedDay = _days.firstWhere(
      (d) => d.year == initDate.year && d.month == initDate.month && d.day == initDate.day,
      orElse: () => _days[1],
    );

    final t = widget.initialTime ?? const TimeOfDay(hour: 8, minute: 0);
    _hour = t.hour;
    _minuteIndex = (t.minute / 5).round().clamp(0, 11);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minCtrl = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required ValueChanged<int> onChanged,
    required String Function(int) label,
  }) {
    return SizedBox(
      width: 64,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 34,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, i) => Center(
            child: Text(
              label(i),
              style: TextStyle(
                fontSize: i == selected ? 19 : 15,
                fontWeight: i == selected ? FontWeight.w800 : FontWeight.w400,
                color: i == selected ? context.textC : context.subC.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardC,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4, decoration: BoxDecoration(
            color: context.subC.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(99),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.textC)),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: TextStyle(fontSize: 11.5, color: context.subC, height: 1.35)),
            ]),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _days[i];
                final sel = d.year == _selectedDay.year && d.month == _selectedDay.month && d.day == _selectedDay.day;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = d),
                  child: Container(
                    width: 50,
                    decoration: BoxDecoration(
                      gradient: sel ? kGradient : null,
                      color: sel ? null : context.cardC,
                      borderRadius: BorderRadius.circular(14),
                      border: sel ? null : Border.all(color: const Color(0xFFDDE3F0)),
                    ),
                    alignment: Alignment.center,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_weekdays[d.weekday - 1], style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : context.textC,
                      )),
                      const SizedBox(height: 2),
                      Text('${d.day}', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: sel ? Colors.white : context.textC,
                      )),
                    ]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Stack(alignment: Alignment.center, children: [
              Container(
                height: 38,
                decoration: BoxDecoration(color: kTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              ),
              SizedBox(
                height: 168,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _wheel(
                    controller: _hourCtrl, count: 24, selected: _hour,
                    onChanged: (i) => setState(() => _hour = i),
                    label: (i) => i.toString().padLeft(2, '0'),
                  ),
                  Text(':', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.textC)),
                  _wheel(
                    controller: _minCtrl, count: 12, selected: _minuteIndex,
                    onChanged: (i) => setState(() => _minuteIndex = i),
                    label: (i) => (i * 5).toString().padLeft(2, '0'),
                  ),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    side: BorderSide(color: context.divC),
                  ),
                  child: Text('Отмена', style: TextStyle(color: context.textC, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(
                    context,
                    DateTimePick(_selectedDay, TimeOfDay(hour: _hour, minute: _minuteIndex * 5)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(99)),
                    alignment: Alignment.center,
                    child: const Text('Подтвердить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
