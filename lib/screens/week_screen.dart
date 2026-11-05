import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../state/week_state.dart';
import '../utils/schedule.dart';
import '../widgets/day_strip.dart';
import '../widgets/theme.dart';
import 'course_form.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _tab = 0;

  // Pushed routes sit beside us: hand over the same brain.
  Future<void> _openForm([Course? course]) async {
    final week = context.read<WeekState>();
    final day = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<WeekState>.value(
          value: week,
          child: CourseForm(course: course, initialDay: week.day),
        ),
      ),
    );
    if (day != null) week.setDay(day);
  }

  Future<void> _confirmDelete(Course course) async {
    // Read before the first await.
    final week = context.read<WeekState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text('Delete ${course.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: clashRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await week.remove(course);
    } on FirebaseException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete: ${e.code}')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${course.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => week.restore(course),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final week = context.watch<WeekState>();
    final pairs = week.clashes;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'My Week' : 'Clashes this week'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _body(week),
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              tooltip: 'Add course',
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GNav(
            selectedIndex: _tab,
            onTabChange: (i) => setState(() => _tab = i),
            gap: 8,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            color: slate,
            activeColor: Colors.white,
            tabBackgroundColor: pairs.isNotEmpty && _tab == 1 ? clashRed : ink,
            tabs: [
              const GButton(icon: Icons.calendar_view_week, text: 'Week'),
              GButton(
                icon: Icons.warning_amber,
                iconColor: pairs.isEmpty ? slate : clashRed,
                text: pairs.isEmpty ? 'Clashes' : 'Clashes (${pairs.length})',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(WeekState week) {
    if (week.error != null) {
      return _Message(icon: Icons.cloud_off, text: week.error!);
    }
    if (week.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _tab == 1 ? _clashesView(week) : _weekView(week);
  }

  Widget _clashesView(WeekState week) {
    final pairs = week.clashes;
    if (pairs.isEmpty) {
      return const _Message(
        icon: Icons.check_circle_outline,
        text: 'No clashes this week',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        for (final (a, b) in pairs)
          _Striped(
            color: clashRed,
            child: ListTile(
              title: Text(
                '${a.name} and ${b.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${dayNames[a.day]}: '
                '${formatTime(a.start)}–${formatTime(a.end)} and '
                '${formatTime(b.start)}–${formatTime(b.end)}',
                style: const TextStyle(fontFeatures: tabular),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.read<WeekState>().setDay(a.day);
                setState(() => _tab = 0);
              },
            ),
          ),
      ],
    );
  }

  Widget _weekView(WeekState week) {
    final visible = week.visible;
    final String? emptyMessage = week.courses.isEmpty
        ? 'No courses yet.\nTap + to add your first one.'
        : week.dayCourses.isEmpty
            ? 'No classes on ${dayNames[week.day]}'
            : visible.isEmpty
                ? 'No course on ${dayNames[week.day]} matches "${week.query}"'
                : null;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Week total: ${formatDuration(week.weekMinutes)}',
            style: text.bodyMedium?.copyWith(color: slate),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DayStrip(
            minutes: week.minutesPerDay,
            clashDays: week.clashDays,
            selected: week.day,
            onSelect: (i) => context.read<WeekState>().setDay(i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search courses',
              isDense: true,
            ),
            onChanged: (text) => context.read<WeekState>().setQuery(text),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            '${dayNames[week.day]} · ${formatDuration(week.dayMinutes)}',
            style: text.titleMedium?.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: emptyMessage != null
              ? _Message(icon: Icons.event_available, text: emptyMessage)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: _dayItems(week, visible),
                ),
        ),
      ],
    );
  }

  List<Widget> _dayItems(WeekState week, List<Course> dayCourses) {
    final items = <Widget>[];
    var busyUntil = dayCourses.first.start;
    for (final c in dayCourses) {
      if (c.start > busyUntil) {
        items.add(_FreeGap(from: busyUntil, to: c.start));
      }
      items.add(_courseRow(week, c));
      if (c.end > busyUntil) busyUntil = c.end;
    }
    return items;
  }

  Widget _courseRow(WeekState week, Course c) {
    final clashes = week.clashesOf(c);
    final clashing = clashes.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTime(c.start),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ink,
                    fontFeatures: tabular,
                  ),
                ),
                Text(
                  formatTime(c.end),
                  style: const TextStyle(
                    fontSize: 12,
                    color: slate,
                    fontFeatures: tabular,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _Striped(
            color: clashing ? clashRed : courseColor(c.name),
            tint: clashing,
            child: ListTile(
              titleAlignment: ListTileTitleAlignment.center,
              onTap: () => _openForm(c),
              title: Text(
                c.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: clashing ? clashRed : ink,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDuration(c.duration),
                    style: const TextStyle(color: slate),
                  ),
                  if (clashing)
                    Text(
                      'Clashes with ${clashes.map((o) => o.name).join(', ')}',
                      style: const TextStyle(
                        color: clashRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: slate),
                onPressed: () => _confirmDelete(c),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A card with a coloured stripe on its left edge.
class _Striped extends StatelessWidget {
  const _Striped({required this.color, required this.child, this.tint = false});

  final Color color;
  final Widget child;
  final bool tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tint ? const Color(0xFFFDEEEF) : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: color),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _FreeGap extends StatelessWidget {
  const _FreeGap({required this.from, required this.to});

  final int from;
  final int to;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 6, 0, 6),
      child: Row(
        children: [
          const Icon(Icons.local_cafe_outlined, size: 16, color: slate),
          const SizedBox(width: 8),
          Text(
            'Free ${formatTime(from)}–${formatTime(to)} · '
            '${formatDuration(to - from)}',
            style: const TextStyle(color: slate, fontFeatures: tabular),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: slate),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: slate, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
