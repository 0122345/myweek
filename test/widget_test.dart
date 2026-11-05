import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:myweek/models/course.dart';
import 'package:myweek/repositories/course_repository.dart';
import 'package:myweek/screens/week_screen.dart';
import 'package:myweek/state/week_state.dart';
import 'package:myweek/utils/schedule.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Course c(int id, int day, String start, String end, [String? name]) => Course(
      id: '$id',
      name: name ?? 'C$id',
      day: day,
      start: parseTime(start)!,
      end: parseTime(end)!,
    );

/// An in-memory repository: behaves like Firestore (changes come back
/// through the stream) but needs no network and no Firebase.
class FakeCourseRepository implements CourseRepository {
  FakeCourseRepository(List<Course> initial) : _data = [...initial];

  final List<Course> _data;
  final _controller = StreamController<List<Course>>.broadcast();
  var _nextId = 100;

  @override
  String get uid => 'test-user';

  void _emit() => _controller.add(List.unmodifiable(_data));

  @override
  Stream<List<Course>> watchAll() {
    scheduleMicrotask(_emit);
    return _controller.stream;
  }

  Course _withId(Course x, String id) =>
      Course(id: id, name: x.name, day: x.day, start: x.start, end: x.end);

  @override
  Future<void> add(Course course) async {
    _data.add(_withId(course, '${_nextId++}'));
    _emit();
  }

  @override
  Future<void> update(String id, Course course) async {
    _data[_data.indexWhere((x) => x.id == id)] = _withId(course, id);
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _data.removeWhere((x) => x.id == id);
    _emit();
  }

  @override
  Future<void> restore(Course course) async {
    _data.add(course);
    _emit();
  }

  @override
  Future<void> addSamples() async {}
}

List<Course> sample() => [
      c(1, 0, '08:00', '10:00', 'Maths'),
      c(2, 0, '10:00', '11:30', 'Physics'),
      c(3, 1, '09:00', '11:00', 'Chemistry'),
      c(4, 1, '10:30', '12:00', 'Biology'),
    ];

Future<WeekState> pumpWeek(WidgetTester tester, [List<Course>? courses]) async {
  // A phone-sized window (the default 800x600 test window is too short).
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final state = WeekState(FakeCourseRepository(courses ?? sample()));
  await tester.pumpWidget(
    ChangeNotifierProvider<WeekState>.value(
      value: state,
      child: const MaterialApp(home: WeekScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('times', () {
    test('parses and formats HH:MM', () {
      expect(parseTime('08:30'), 510);
      expect(formatTime(510), '08:30');
      expect(formatDuration(210), '3h 30m');
      expect(formatDuration(120), '2h');
      expect(formatDuration(45), '45m');
    });

    test('refuses bad times', () {
      for (final bad in ['8h', '25:00', '10:75', '', 'abc', '10:5']) {
        expect(parseTime(bad), isNull, reason: bad);
        expect(timeError(bad), isNotNull, reason: bad);
      }
    });
  });

  group('clashes', () {
    test('touching courses do not clash', () {
      expect(
        c(1, 0, '10:00', '11:00').clashesWith(c(2, 0, '11:00', '12:00')),
        isFalse,
      );
    });

    test('overlapping courses clash both ways', () {
      final a = c(1, 0, '09:00', '11:00');
      final b = c(2, 0, '10:30', '12:00');
      expect(a.clashesWith(b), isTrue);
      expect(b.clashesWith(a), isTrue);
    });

    test('different days never clash', () {
      expect(
        c(1, 0, '09:00', '11:00').clashesWith(c(2, 1, '09:00', '11:00')),
        isFalse,
      );
    });

    test('week clashes lists each pair once', () {
      final all = [
        c(1, 0, '09:00', '11:00'),
        c(2, 0, '10:00', '12:00'),
        c(3, 2, '09:00', '10:00'),
      ];
      expect(weekClashes(all).length, 1);
    });
  });

  test('day is sorted by start time and totals add up', () {
    final all = [
      c(1, 0, '10:00', '11:30'),
      c(2, 0, '08:00', '10:00'),
      c(3, 0, '07:00', '07:30'),
    ];
    expect(coursesOn(all, 0).map((x) => x.id), ['3', '2', '1']);
    expect(formatDuration(totalMinutes(coursesOn(all, 0))), '4h');
  });

  test('free time between classes', () {
    final day = coursesOn([
      c(1, 0, '08:00', '12:00'),
      c(2, 0, '09:00', '10:00'), // inside the first, no gap
      c(3, 0, '14:00', '15:00'),
    ], 0);
    expect(freeTimes(day), [(720, 840)]);
  });

  group('WeekState (the brain)', () {
    test('starts loading, then receives the list and notifies', () async {
      final state = WeekState(FakeCourseRepository(sample()));
      expect(state.loading, isTrue);
      var notified = 0;
      state.addListener(() => notified++);
      await Future<void>.delayed(Duration.zero);
      expect(state.loading, isFalse);
      expect(state.courses.length, 4);
      expect(notified, greaterThan(0));
      state.dispose();
    });

    test('computed values follow the data', () async {
      final state = WeekState(FakeCourseRepository(sample()));
      await Future<void>.delayed(Duration.zero);
      expect(formatDuration(state.weekMinutes), '7h');
      expect(state.clashes.length, 1);
      await state.add(c(0, 2, '08:00', '09:00', 'Art'));
      await Future<void>.delayed(Duration.zero);
      expect(formatDuration(state.weekMinutes), '8h');
      state.dispose();
    });

    test('day filter and search are getters over the same list', () async {
      final state = WeekState(FakeCourseRepository(sample()));
      await Future<void>.delayed(Duration.zero);
      expect(state.visible.map((x) => x.name), ['Maths', 'Physics']);
      state.setDay(1);
      expect(state.visible.map((x) => x.name), ['Chemistry', 'Biology']);
      state.setQuery('bio');
      expect(state.visible.map((x) => x.name), ['Biology']);
      expect(state.courses.length, 4, reason: 'filtering never copies data');
      state.dispose();
    });
  });

  group('screens', () {
    testWidgets('Monday shows 3h 30m with no clash', (tester) async {
      await pumpWeek(tester);
      expect(find.text('Monday · 3h 30m'), findsOneWidget);
      expect(find.textContaining('Clashes with'), findsNothing);

      await tester.tap(find.text('Tue'));
      await tester.pump();
      expect(find.text('Clashes with Biology'), findsOneWidget);
      expect(find.text('Clashes with Chemistry'), findsOneWidget);

      await tester.tap(find.text('Wed'));
      await tester.pump();
      expect(find.text('No classes on Wednesday'), findsOneWidget);
    });

    testWidgets('adding an early course puts it first', (tester) async {
      await pumpWeek(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Art');
      await tester.enterText(fields.at(1), '07:00');
      await tester.enterText(fields.at(2), '07:45');
      await save(tester);
      await tester.pumpAndSettle();

      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title as Text).data)
          .toList();
      expect(titles, ['Art', 'Maths', 'Physics']);
    });

    testWidgets('form refuses end before start', (tester) async {
      await pumpWeek(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Art');
      await tester.enterText(fields.at(1), '10:00');
      await tester.enterText(fields.at(2), '09:00');
      await save(tester);
      await tester.pump();
      expect(
          find.text('End time must be after the start time'), findsOneWidget);
    });

    testWidgets('form shows live data from the brain', (tester) async {
      await pumpWeek(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Week total: 7h · 4 courses'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), '09:00');
      await tester.enterText(fields.at(2), '09:30');
      await tester.pump();
      expect(find.text('Clashes with Maths'), findsOneWidget);
    });

    testWidgets('editing a time to remove the overlap clears red on both', (
      tester,
    ) async {
      await pumpWeek(tester);
      await tester.tap(find.text('Tue'));
      await tester.pump();
      expect(find.textContaining('Clashes with'), findsNWidgets(2));

      await tester.tap(find.text('Biology'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '11:00');
      await save(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Clashes with'), findsNothing);
    });

    testWidgets('Clashes tab lists every clash of the week', (tester) async {
      await pumpWeek(tester);
      expect(find.text('Clashes (1)'), findsOneWidget);
      await tester.tap(find.byType(GButton).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Chemistry and Biology'), findsOneWidget);
    });

    testWidgets('delete asks Are you sure? first', (tester) async {
      await pumpWeek(tester);
      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Maths'), findsNothing);
      expect(find.text('Monday · 1h 30m'), findsOneWidget);
    });

    testWidgets('search narrows the day list', (tester) async {
      await pumpWeek(tester);
      await tester.enterText(find.byType(TextField).first, 'phy');
      await tester.pump();
      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('Maths'), findsNothing);
    });
  });
}
