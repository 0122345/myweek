import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

class Course {
  final String id;
  final String name;
  final int day;  
  final int start;  
  final int end; // minutes since midnight

  const Course({
    this.id = '',
    required this.name,
    required this.day,
    required this.start,
    required this.end,
  });

  int get duration => end - start;
  Map<String, dynamic> toMap() => {
        'name': name,
        'day': day,
        'start': start,
        'end': end,
      };

  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Course(
      id: doc.id,
      name: data['name'] as String,
      day: (data['day'] as num).toInt(),
      start: (data['start'] as num).toInt(),
      end: (data['end'] as num).toInt(),
    );
  }


 
  bool clashesWith(Course other) =>
      id != other.id &&
      day == other.day &&
      start < other.end &&
      other.start < end;
}

 
int? parseTime(String text) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final h = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  if (h > 23 || m > 59) return null;
  return h * 60 + m;
}

/// Turns 510 back into "08:30".
String formatTime(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Turns 210 into "3h 30m".
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
    courses.fold(0, (sum, c) => sum + c.duration);

 
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

// The signed-in user's courses: users/{uid}/courses
CollectionReference<Map<String, dynamic>> myCourses() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('courses');
}

// Sample data, written once when a new account is created.
Future<void> addSampleCourses() async {
  const samples = [
    Course(name: 'Multivariable', day: 0, start: 8 * 60, end: 10 * 60),
    Course(name: 'ICDL', day: 0, start: 10 * 60, end: 11 * 60 + 30),
    Course(name: 'MOBILE', day: 1, start: 9 * 60, end: 11 * 60),
    Course(name: 'WEBTECH', day: 1, start: 10 * 60 + 30, end: 12 * 60),
    Course(name: 'English', day: 1, start: 14 * 60, end: 15 * 60),
    Course(name: 'ENTREPRENEURSHIP', day: 3, start: 13 * 60, end: 15 * 60),
    Course(name: 'Programming', day: 3, start: 8 * 60 + 30, end: 10 * 60),
  ];
  final batch = FirebaseFirestore.instance.batch();
  for (final c in samples) {
    batch.set(myCourses().doc(), c.toMap());
  }
  await batch.commit();
}
