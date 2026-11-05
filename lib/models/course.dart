import 'package:cloud_firestore/cloud_firestore.dart';

const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

class Course {
  final String id;
  final String name;
  final int day; // 0 = Monday ... 4 = Friday
  final int start; // minutes since midnight
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

/// "08:30" -> 510, or null when invalid.
int? parseTime(String text) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final h = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  if (h > 23 || m > 59) return null;
  return h * 60 + m;
}
