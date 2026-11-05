import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../repositories/course_repository.dart';
import '../repositories/settings_repository.dart';
import '../utils/schedule.dart';

/// The brain: holds courses, computes values, notifies screens.
class WeekState extends ChangeNotifier {
  WeekState(this._repo, [SettingsRepository? settings])
      : _settings = settings ?? SettingsRepository() {
    debugPrint('Brain born for ${_repo.uid}');
    // Open the pipe to the backend, once.
    _subscription = _repo.watchAll().listen(
      (list) {
        _courses = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _error = 'Could not load your courses.\n$e';
        notifyListeners();
      },
    );
    _restoreDay();
  }

  final CourseRepository _repo;
  final SettingsRepository _settings;
  StreamSubscription<List<Course>>? _subscription;
  bool _disposed = false;

  // Private data: only the brain changes it.
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;
  int _day = 0; // Filter: day shown in week view.
  String _query = ''; // Search text, lower-case.

  List<Course> get courses => _courses;
  bool get loading => _loading;
  String? get error => _error;
  int get day => _day;
  String get query => _query;

  // Computed (Habit 2): never stored.

  List<Course> get visible {
    final list = coursesOn(_courses, _day);
    if (_query.isEmpty) return list;
    return list.where((c) => c.name.toLowerCase().contains(_query)).toList();
  }

  List<Course> get dayCourses => coursesOn(_courses, _day);

  int get weekMinutes => totalMinutes(_courses);
  int get dayMinutes => totalMinutes(dayCourses);
  List<(Course, Course)> get clashes => weekClashes(_courses);
  List<int> get minutesPerDay => [
        for (var d = 0; d < dayNames.length; d++)
          totalMinutes(coursesOn(_courses, d)),
      ];
  Set<int> get clashDays => {for (final (a, _) in clashes) a.day};
  List<Course> clashesOf(Course course) => clashesFor(course, _courses);

  void setDay(int value) {
    if (value < 0 || value >= dayNames.length) return;
    _day = value;
    notifyListeners();
    _settings.saveDay(value);
  }

  void setQuery(String value) {
    _query = value.trim().toLowerCase();
    notifyListeners();
  }

  Future<void> _restoreDay() async {
    try {
      final saved = await _settings.loadDay();
      if (_disposed || saved == null) return;
      if (saved >= 0 && saved < dayNames.length) {
        _day = saved;
        notifyListeners();
      }
    } catch (_) {
      // Keep Monday.
    }
  }

  // Actions go to the repository; results return via the pipe.
  Future<void> add(Course course) => _repo.add(course);
  Future<void> edit(String id, Course course) => _repo.update(id, course);
  Future<void> remove(Course course) => _repo.delete(course.id);
  Future<void> restore(Course course) => _repo.restore(course);

  @override
  void dispose() {
    debugPrint('Brain disposed: pipe closed');
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
