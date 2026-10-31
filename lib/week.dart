
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'course.dart';
import 'course_form.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      myCourses().orderBy('start').snapshots();
  int _day = 0;
  int _tab = 0;

 @override
 void initState(){
  super.initState();
  _loadDay();
 }
 Future<void> _loadDay() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('selected_day');
    if (saved != null && saved >= 0 && saved < dayNames.length && mounted) {
      setState(() => _day = saved);
    }
  }

  Future<void> _setDay(int day) async {
    setState(() => _day = day);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_day', day);
  }


  Future<void> _openForm([Course? course]) async {
    final day = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CourseForm(course: course, initialDay: _day),
      ),
    );
    if (day != null) _setDay(day); // show the day the course ended up on
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
    if (ok != true) return;
    try {
      await myCourses().doc(course.id).delete();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: ${e.code}')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${course.name}'),
        action: SnackBarAction(
          label: 'Undo',
          // Undo: write the same data back.
          onPressed: () => myCourses().doc(course.id).set(course.toMap()),
        ),
      ),
    );
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
                onTap: () {
                _setDay(a.day);
                setState(() => _tab = 0);
              },
            ),
          ),
      ],
    );
  }

    Widget _weekView(List<Course> courses) {
    final dayCourses = coursesOn(courses, _day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Week total: ${formatDuration(totalMinutes(courses))}',
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
                  onSelected: (_) => _setDay(i),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      courses.isEmpty
                          ? 'No courses yet.\nTap + to add your first one.'
                          : 'No classes on ${dayNames[_day]}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: _dayItems(dayCourses, courses),
                ),
        ),
      ],
    );
  }

  Widget _body(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    List<Course> courses,
    List<(Course, Course)> pairs,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load your courses.\n${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return _tab == 1 ? _clashesView(pairs) : _weekView(courses);
  }



  @override
  Widget build(BuildContext context) {
     return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        // Everything below is calculated again each time Firestore sends data.
        final courses = snapshot.hasData
            ? snapshot.data!.docs.map(Course.fromDoc).toList()
            : <Course>[];
        final pairs = weekClashes(courses);

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
          body: _body(snapshot, courses, pairs),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                activeColor: Theme.of(context).colorScheme.onPrimaryContainer,
                tabBackgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                tabs: [
                  const GButton(icon: Icons.calendar_view_week, text: 'Week'),
                  GButton(
                    icon: Icons.warning_amber,
                    text: pairs.isEmpty
                        ? 'Clashes'
                        : 'Clashes (${pairs.length})',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _dayItems(List<Course> dayCourses, List<Course> all) {
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
      items.add(_courseCard(c, all));
      if (c.end > busyUntil) busyUntil = c.end;
    }
    return items;
  }

  Widget _courseCard(Course c, List<Course> all) {
    final clashes = clashesFor(c, all);
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
