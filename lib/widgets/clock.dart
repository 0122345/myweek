import 'package:flutter/material.dart';
// Hide the package's own formatTime; use ours.
import 'package:progressive_time_picker/progressive_time_picker.dart'
    hide formatTime;

import '../models/course.dart';
import '../utils/schedule.dart';

/// Round start/end picker bound to the form's fields.
class Clock extends StatelessWidget {
  const Clock({super.key, required this.start, required this.end});

  final TextEditingController start;
  final TextEditingController end;

  // Defaults to 08:00–10:00 until times are valid.
  int get _pickerStart => parseTime(start.text) ?? 8 * 60;
  int get _pickerEnd => parseTime(end.text) ?? 10 * 60;

  PickedTime _picked(int minutes) =>
      PickedTime(h: minutes ~/ 60, m: minutes % 60);

  int _minutes(PickedTime t) => (t.h % 24) * 60 + t.m;

  void _onPicked(PickedTime s, PickedTime e, bool? _) {
    start.text = formatTime(_minutes(s));
    end.text = formatTime(_minutes(e));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TimePicker(
      initTime: _picked(_pickerStart),
      endTime: _picked(_pickerEnd),
      height: 240,
      width: 240,
      onSelectionChange: _onPicked,
      onSelectionEnd: _onPicked,
      decoration: TimePickerDecoration(
        baseColor: scheme.surfaceContainerHighest,
        sweepDecoration: TimePickerSweepDecoration(
          pickerStrokeWidth: 24,
          pickerColor: scheme.primary,
          showConnector: true,
        ),
        initHandlerDecoration: TimePickerHandlerDecoration(
          color: scheme.onPrimary,
          shape: BoxShape.circle,
          radius: 10,
          icon: Icon(Icons.play_arrow, size: 14, color: scheme.primary),
        ),
        endHandlerDecoration: TimePickerHandlerDecoration(
          color: scheme.onPrimary,
          shape: BoxShape.circle,
          radius: 10,
          icon: Icon(Icons.stop, size: 14, color: scheme.primary),
        ),
      ),
      child: Text(
        '${formatTime(_pickerStart)}–${formatTime(_pickerEnd)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
