import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _timezones = [
  'GMT-12:00 International Date Line West',
  'GMT-11:00 Coordinated Universal Time -11',
  'GMT-10:00 Hawaii',
  'GMT-09:00 Alaska',
  'GMT-08:00 Pacific Time (US & Canada)',
  'GMT-07:00 Mountain Time (US & Canada)',
  'GMT-06:00 Central Time (US & Canada)',
  'GMT-05:00 Eastern Time (US & Canada)',
  'GMT-04:00 Atlantic Time (Canada)',
  'GMT-03:00 Buenos Aires, Georgetown',
  'GMT-02:00 Coordinated Universal Time -2',
  'GMT-01:00 Azores',
  'GMT+00:00 London, Dublin, Lisbon',
  'GMT+01:00 Amsterdam, Berlin, Paris, Rome',
  'GMT+02:00 Athens, Bucharest, Cairo',
  'GMT+03:00 Moscow, St. Petersburg',
  'GMT+03:30 Tehran',
  'GMT+04:00 Abu Dhabi, Muscat',
  'GMT+04:30 Kabul',
  'GMT+05:00 Islamabad, Karachi',
  'GMT+05:30 Chennai, Kolkata, Mumbai, New Delhi',
  'GMT+05:45 Kathmandu',
  'GMT+06:00 Astana, Dhaka',
  'GMT+06:30 Yangon (Rangoon)',
  'GMT+07:00 Indochina Time, Western Indonesia Time',
  'GMT+08:00 Taiwan Standard Time, Singapore Standard Time, China Standard Time',
  'GMT+09:00 Japan Standard Time, Korean Standard Time',
  'GMT+09:30 Australian Central Standard Time',
  'GMT+10:00 Australian Eastern Standard Time',
  'GMT+11:00 New Caledonia Standard Time',
  'GMT+12:00 New Zealand Standard Time, Fiji Standard Time',
  'GMT+13:00 Samoa Standard Time',
  'GMT+14:00 Line Islands Time',
];

Future<DateTime?> showEditDateTimeDialog(BuildContext context, DateTime initial) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _EditDateTimeDialog(initial: initial),
  );
}

class _EditDateTimeDialog extends StatefulWidget {
  final DateTime initial;
  const _EditDateTimeDialog({required this.initial});

  @override
  State<_EditDateTimeDialog> createState() => _EditDateTimeDialogState();
}

class _EditDateTimeDialogState extends State<_EditDateTimeDialog> {
  late bool _isPm;
  late String _selectedTz;

  late final TextEditingController _yearCtrl;
  late final TextEditingController _monthCtrl;
  late final TextEditingController _dayCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  late final TextEditingController _secondCtrl;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _isPm      = i.hour >= 12;
    _selectedTz = 'GMT+10:00 Australian Eastern Standard Time';
    _yearCtrl   = TextEditingController(text: i.year.toString());
    _monthCtrl  = TextEditingController(text: i.month.toString().padLeft(2, '0'));
    _dayCtrl    = TextEditingController(text: i.day.toString().padLeft(2, '0'));
    _hourCtrl   = TextEditingController(
        text: (i.hour % 12 == 0 ? 12 : i.hour % 12).toString().padLeft(2, '0'));
    _minuteCtrl = TextEditingController(text: i.minute.toString().padLeft(2, '0'));
    _secondCtrl = TextEditingController(text: i.second.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _yearCtrl.dispose(); _monthCtrl.dispose(); _dayCtrl.dispose();
    _hourCtrl.dispose(); _minuteCtrl.dispose(); _secondCtrl.dispose();
    super.dispose();
  }

  DateTime? get _result {
    final year   = int.tryParse(_yearCtrl.text);
    final month  = int.tryParse(_monthCtrl.text);
    final day    = int.tryParse(_dayCtrl.text);
    final hour12 = int.tryParse(_hourCtrl.text);
    final minute = int.tryParse(_minuteCtrl.text);
    final second = int.tryParse(_secondCtrl.text);

    if (year == null || month == null || day == null ||
        hour12 == null || minute == null || second == null) {
      return null;
    }
    if (year < 1900 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > DateUtils.getDaysInMonth(year, month)) return null;
    if (hour12 < 1 || hour12 > 12) return null;
    if (minute < 0 || minute > 59) return null;
    if (second < 0 || second > 59) return null;

    final hour24 = _isPm
        ? (hour12 == 12 ? 12 : hour12 + 12)
        : (hour12 == 12 ? 0  : hour12);
    return DateTime(year, month, day, hour24, minute, second);
  }

  String get _formattedSubtitle {
    final dt = _result;
    if (dt == null) return 'Invalid date';
    final weekday = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][dt.weekday - 1];
    final month   = ['January','February','March','April','May','June','July',
        'August','September','October','November','December'][dt.month - 1];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$weekday, $month ${dt.day}, ${dt.year}, $h:$m ${_isPm ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2B2B2F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 560,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit date & time',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              ValueListenableBuilder(
                valueListenable: _yearCtrl,
                builder: (_, _, _) => ValueListenableBuilder(
                  valueListenable: _monthCtrl,
                  builder: (_, _, _) => ValueListenableBuilder(
                    valueListenable: _dayCtrl,
                    builder: (_, _, _) => ValueListenableBuilder(
                      valueListenable: _hourCtrl,
                      builder: (_, _, _) => ValueListenableBuilder(
                        valueListenable: _minuteCtrl,
                        builder: (_, _, _) => Text(
                          _formattedSubtitle,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _fieldBox(label: 'Year',  ctrl: _yearCtrl,   maxLength: 4, maxVal: 2100, minVal: 1900),
                  const SizedBox(width: 8),
                  _fieldBox(label: 'Month', ctrl: _monthCtrl,  maxLength: 2, maxVal: 12,   minVal: 1),
                  const SizedBox(width: 8),
                  _fieldBox(label: 'Day',   ctrl: _dayCtrl,    maxLength: 2, maxVal: 31,   minVal: 1),
                  const SizedBox(width: 8),
                  _fieldBox(label: 'Time',  ctrl: _hourCtrl,   maxLength: 2, maxVal: 12,   minVal: 1),
                  _separator(),
                  _fieldBox(label: '',      ctrl: _minuteCtrl, maxLength: 2, maxVal: 59,   minVal: 0),
                  _separator(),
                  _fieldBox(label: '',      ctrl: _secondCtrl, maxLength: 2, maxVal: 59,   minVal: 0),
                  const SizedBox(width: 8),
                  _ampmBox(),
                ],
              ),

              const SizedBox(height: 12),

              Theme(
                data: Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                ),
                child: DropdownMenu<String>(
                  width: 512,
                  initialSelection: _selectedTz,
                  onSelected: (v) { if (v != null) setState(() => _selectedTz = v); },
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStatePropertyAll(const Color(0xFF2B2B2F)),
                    surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFF4A4A50), width: 0.5),
                    )),
                    maximumSize: WidgetStatePropertyAll(const Size(502, 220)),
                    elevation: WidgetStatePropertyAll(8),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFF3A3A3F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF7BB8F5), width: 1.5),
                    ),
                  ),
                  textStyle: const TextStyle(color: Colors.white, fontSize: 13),
                  label: const Text('Time zone',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailingIcon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white54, size: 20),
                  selectedTrailingIcon: const Icon(Icons.keyboard_arrow_up,
                      color: Colors.white54, size: 20),
                  dropdownMenuEntries: _timezones.map((tz) => DropdownMenuEntry<String>(
                    value: tz,
                    label: tz,
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected) || tz == _selectedTz
                              ? Colors.white
                              : Colors.white70),
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (tz == _selectedTz) return const Color(0xFF3D3D45);
                        if (states.contains(WidgetState.hovered)) return const Color(0xFF35353A);
                        return Colors.transparent;
                      }),
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(
                          fontSize: 13,
                          fontWeight: tz == _selectedTz ? FontWeight.w500 : FontWeight.w300,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final dt = _result;
                      if (dt != null) Navigator.pop(context, dt);
                    },
                    child: const Text('Save',
                        style: TextStyle(color: Color(0xFF7BB8F5), fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldBox({
    required String label,
    required TextEditingController ctrl,
    required int maxLength,
    required int maxVal,
    required int minVal,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            )
          else
            const SizedBox(height: 15),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.left,
            style: const TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w300),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(maxLength),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              filled: true,
              fillColor: const Color(0xFF3A3A3F),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF7BB8F5), width: 1.5)),
            ),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null && (parsed < minVal || parsed > maxVal)) {
                ctrl.value = ctrl.value;
              }
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _separator() => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(' : ',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w300)),
      );

  Widget _ampmBox() {
    return InkWell(
      onTap: () => setState(() => _isPm = !_isPm),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 52,
        height: 40,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3F),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _isPm ? 'PM' : 'AM',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w300,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}