import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:progressive_time_picker/progressive_time_picker.dart'
    show
        PickedTime,
        TimePicker,
        TimePickerDecoration,
        TimePickerHandlerDecoration,
        TimePickerSweepDecoration;

import 'course.dart';

class CourseForm extends StatefulWidget {
  final Course? course;  
  final int initialDay;

  const CourseForm({
    super.key,
    this.course,
    required this.initialDay,
  });

  @override
  State<CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<CourseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late int _day;
  bool _busy = false;

  bool get _editing => widget.course != null;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _name = TextEditingController(text: c?.name ?? '');
    _start = TextEditingController(text: c == null ? '' : formatTime(c.start));
    _end = TextEditingController(text: c == null ? '' : formatTime(c.end));
    _day = c?.day ?? widget.initialDay;
    // Typing a valid time moves the clock handles too.
    _start.addListener(_refresh);
    _end.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  // The clock shows the typed times; until they are valid it shows 08:00–10:00.
  int get _pickerStart => parseTime(_start.text) ?? 8 * 60;
  int get _pickerEnd => parseTime(_end.text) ?? 10 * 60;

  PickedTime _picked(int minutes) =>
      PickedTime(h: minutes ~/ 60, m: minutes % 60);

  int _minutes(PickedTime t) => (t.h % 24) * 60 + t.m;

   
  void _onPicked(PickedTime start, PickedTime end, bool? _) {
    _start.text = formatTime(_minutes(start));
    _end.text = formatTime(_minutes(end));
  }

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  String? _endValidator(String? text) {
    final error = timeError(text ?? '');
    if (error != null) return error;
    final start = parseTime(_start.text);
    final end = parseTime(text!)!;
    if (start != null && end <= start) {
      return 'End time must be after the start time';
    }
    return null;
  }

 Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final course = Course(
      id: widget.course?.id ?? '',
      name: _name.text.trim(),
      day: _day,
      start: parseTime(_start.text)!,
      end: parseTime(_end.text)!,
    );
    try {
      if (_editing) {
        await myCourses().doc(course.id).update(course.toMap());
      } else {
        await myCourses().add(course.toMap());
      }
      if (mounted) Navigator.pop(context, course.day);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: ${e.code}')),
      );
    }
  }


  Widget _clock(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit course' : 'Add course')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Course name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter a course name'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Day'),
              items: [
                for (var i = 0; i < dayNames.length; i++)
                  DropdownMenuItem(value: i, child: Text(dayNames[i])),
              ],
              onChanged: (v) => setState(() => _day = v!),
            ),
            const SizedBox(height: 16),
            Center(child: _clock(context)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _start,
                    decoration: const InputDecoration(
                      labelText: 'Start',
                      hintText: '08:00',
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (v) => timeError(v ?? ''),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _end,
                    decoration: const InputDecoration(
                      labelText: 'End',
                      hintText: '10:00',
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: _endValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
