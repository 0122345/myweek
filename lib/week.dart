
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'course.dart';
import 'course_form.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  
  final List<Course> _courses = [
    Course(id: 1, name: 'Multivariable', day: 0, start: 8 * 60, end: 10 * 60),
    Course(id: 2, name: 'ICDL', day: 0, start: 10 * 60, end: 11 * 60 + 30),
    Course(id: 3, name: 'MOBILE', day: 1, start: 9 * 60, end: 11 * 60),
    Course(id: 4, name: 'WEBTECH', day: 1, start: 10 * 60 + 30, end: 12 * 60),
    Course(id: 5, name: 'English', day: 1, start: 14 * 60, end: 15 * 60),
    Course(id: 6, name: 'ENTREPRENEURSHIP', day: 3, start: 13 * 60, end: 15 * 60),
    Course(
      id: 7,
      name: 'Programming',
      day: 3,
      start: 8 * 60 + 30,
      end: 10 * 60,
    ),
  ];
  int _nextId = 8;
  int _day = 0;
  int _tab = 0;  

  Future<void> _openForm([Course? course]) async {
    final result = await Navigator.push<Course>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CourseForm(course: course, initialDay: _day, newId: _nextId),
      ),
    );
    if (result == null) return;
    setState(() {
      final i = _courses.indexWhere((c) => c.id == result.id);
      if (i == -1) {
        _courses.add(result);
        _nextId++;
      } else {
        _courses[i] = result;
      }
      _day = result.day; // show the day the course ended up on
    });
  }

  Future<void> _confirmDelete(Course course) async {
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _courses.removeWhere((c) => c.id == course.id));
    }
  }

   
  Widget _clashesView(List<(Course, Course)> pairs) {
    if (pairs.isEmpty) {
      return const Center(child: Text('No clashes this week'));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final (a, b) in pairs)
          Card(
            color: Colors.red.shade100,
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: Colors.red.shade900),
              title: Text('${a.name} and ${b.name}'),
              subtitle: Text(
                '${dayNames[a.day]}: '
                '${formatTime(a.start)}–${formatTime(a.end)} and '
                '${formatTime(b.start)}–${formatTime(b.end)}',
              ),
              onTap: () => setState(() {
                _day = a.day;
                _tab = 0;
              }),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayCourses = coursesOn(_courses, _day);
    final pairs = weekClashes(_courses);

    return Scaffold(
      appBar: AppBar(title: Text(_tab == 0 ? 'My Week' : 'Clashes this week')),
      body: _tab == 1
          ? _clashesView(pairs)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Week total: ${formatDuration(totalMinutes(_courses))}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < dayShort.length; i++)
                        ChoiceChip(
                          label: Text(dayShort[i]),
                          selected: _day == i,
                          onSelected: (_) => setState(() => _day = i),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${dayNames[_day]} · ${formatDuration(totalMinutes(dayCourses))}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: dayCourses.isEmpty
                      ? Center(child: Text('No classes on ${dayNames[_day]}'))
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: _dayItems(dayCourses),
                        ),
                ),
              ],
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
            activeColor: Theme.of(context).colorScheme.onPrimaryContainer,
            tabBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
            tabs: [
              const GButton(icon: Icons.calendar_view_week, text: 'Week'),
              GButton(
                icon: Icons.warning_amber,
                text: pairs.isEmpty ? 'Clashes' : 'Clashes (${pairs.length})',
              ),
            ],
          ),
        ),
      ),
    );
  }

   
  List<Widget> _dayItems(List<Course> dayCourses) {
    final items = <Widget>[];
    var busyUntil = dayCourses.first.start;
    for (final c in dayCourses) {
      if (c.start > busyUntil) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Free: ${formatTime(busyUntil)}–${formatTime(c.start)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        );
      }
      items.add(_courseCard(c));
      if (c.end > busyUntil) busyUntil = c.end;
    }
    return items;
  }

  Widget _courseCard(Course c) {
    final clashes = clashesFor(c, _courses);
    final clashing = clashes.isNotEmpty;
    return Card(
      color: clashing ? Colors.red.shade100 : null,
      child: ListTile(
        onTap: () => _openForm(c),
        title: Text(
          c.name,
          style: TextStyle(color: clashing ? Colors.red.shade900 : null),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatTime(c.start)}–${formatTime(c.end)} · '
              '${formatDuration(c.duration)}',
            ),
            if (clashing)
              Text(
                'Clashes with ${clashes.map((o) => o.name).join(', ')}',
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(c),
        ),
      ),
    );
  }
}
