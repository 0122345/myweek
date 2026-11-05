import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course.dart';

/// The only class that talks to Firestore, for one user.
class CourseRepository {
  CourseRepository(this.uid);

  final String uid;

  CollectionReference<Map<String, dynamic>> get _courses =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('courses');

  // The list now, and again after every change.
  Stream<List<Course>> watchAll() => _courses
      .orderBy('start')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Course.fromDoc).toList());

  Future<void> add(Course course) => _courses.add(course.toMap());

  Future<void> update(String id, Course course) =>
      _courses.doc(id).update(course.toMap());

  Future<void> delete(String id) => _courses.doc(id).delete();

  /// Undo a delete: write back under the old id.
  Future<void> restore(Course course) =>
      _courses.doc(course.id).set(course.toMap());

  Future<void> addSamples() async {
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
      batch.set(_courses.doc(), c.toMap());
    }
    await batch.commit();
  }
}
