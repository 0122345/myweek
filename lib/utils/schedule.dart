import '../models/course.dart';

/// 510 -> "08:30".
String formatTime(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// 210 -> "3h 30m".
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String? timeError(String text) {
  if (text.trim().isEmpty) return 'Enter a time like 08:00';
  if (parseTime(text) == null) {
    return '"${text.trim()}" is not a valid time. Use HH:MM, e.g. 08:00';
  }
  return null;
}

List<Course> coursesOn(List<Course> all, int day) {
  final list = all.where((c) => c.day == day).toList();
  list.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.end.compareTo(b.end);
  });
  return list;
}

List<Course> clashesFor(Course course, List<Course> all) =>
    all.where(course.clashesWith).toList();

/// Each clashing pair once.
List<(Course, Course)> weekClashes(List<Course> all) {
  final pairs = <(Course, Course)>[];
  for (var day = 0; day < dayNames.length; day++) {
    final list = coursesOn(all, day);
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        if (list[i].clashesWith(list[j])) pairs.add((list[i], list[j]));
      }
    }
  }
  return pairs;
}

int totalMinutes(Iterable<Course> courses) =>
    courses.fold(0, (total, c) => total + c.duration);

List<(int, int)> freeTimes(List<Course> sortedDay) {
  final gaps = <(int, int)>[];
  if (sortedDay.isEmpty) return gaps;
  var busyUntil = sortedDay.first.end;
  for (final c in sortedDay.skip(1)) {
    if (c.start > busyUntil) gaps.add((busyUntil, c.start));
    if (c.end > busyUntil) busyUntil = c.end;
  }
  return gaps;
}
