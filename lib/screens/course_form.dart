import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../state/week_state.dart';
import '../utils/schedule.dart';
import '../widgets/clock.dart';
import '../widgets/theme.dart';

class CourseForm extends StatefulWidget {
  final Course? course;
  final int initialDay;

  const CourseForm({super.key, this.course, required this.initialDay});

  @override
  State<CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<CourseForm> {
  // Ephemeral state: stays here with setState.
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
    _start.addListener(_refresh);
    _end.addListener(_refresh);
  }

  void _refresh() => setState(() {});

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

  /// Typed course, or null while times are invalid.
  Course? get _draft {
    final s = parseTime(_start.text);
    final e = parseTime(_end.text);
    if (s == null || e == null || e <= s) return null;
    return Course(
      id: widget.course?.id ?? '',
      name: _name.text.trim(),
      day: _day,
      start: s,
      end: e,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Read before the first await.
    final week = context.read<WeekState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final course = _draft!;
    try {
      if (_editing) {
        await week.edit(widget.course!.id, course);
      } else {
        await week.add(course);
      }
      if (mounted) Navigator.pop(context, course.day);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save: ${e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step 16: live data from the brain.
    final week = context.watch<WeekState>();
    final draft = _draft;
    final clashes = draft == null ? <Course>[] : week.clashesOf(draft);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit course' : 'Add course')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Summary(
              text: 'Week total: ${formatDuration(week.weekMinutes)} · '
                  '${week.courses.length} courses',
              clashes: clashes,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Course name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a course name' : null,
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
            Center(child: Clock(start: _start, end: _end)),
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
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.text, required this.clashes});

  final String text;
  final List<Course> clashes;

  @override
  Widget build(BuildContext context) {
    final clashing = clashes.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: clashing ? const Color(0xFFFDEEEF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: clashing ? clashRed : line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ink,
              fontFeatures: tabular,
            ),
          ),
          if (clashing) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.warning_amber, size: 18, color: clashRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Clashes with ${clashes.map((c) => c.name).join(', ')}',
                    style: const TextStyle(
                      color: clashRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
