import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/visit_model.dart';
import '../models/trip_model.dart';
import '../models/schedule_model.dart';

/// snapshot event للمزامنة — يحمل النوع (added/modified/removed) والبيانات
class FirestoreEvent<T> {
  final T            data;
  final bool         isRemoved; // true = تم الحذف من Firestore
  const FirestoreEvent(this.data, {this.isRemoved = false});
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _studentsRef =>
      _db.collection(AppConstants.studentsCollection);
  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _db.collection(AppConstants.attendanceCollection);
  CollectionReference<Map<String, dynamic>> get _visitsRef =>
      _db.collection(AppConstants.visitsCollection);
  CollectionReference<Map<String, dynamic>> get _tripsRef =>
      _db.collection(AppConstants.tripsCollection);
  CollectionReference<Map<String, dynamic>> get _bookingsRef =>
      _db.collection(AppConstants.bookingsCollection);
  CollectionReference<Map<String, dynamic>> get _scheduleRef =>
      _db.collection(AppConstants.scheduleCollection);

  // ──────────────────────── الشباب ────────────────────────────────────────────
  Future<void> pushStudent(StudentModel s) async =>
      _studentsRef.doc(s.id).set(s.toMap(), SetOptions(merge: true));

  Future<List<StudentModel>> fetchAllStudents() async {
    final snap = await _studentsRef.get();
    return snap.docs.map((d) => StudentModel.fromMap(d.data())).toList();
  }

  Stream<List<FirestoreEvent<StudentModel>>> watchStudents() =>
      _studentsRef.snapshots().map((snap) => snap.docChanges
          .map((c) => FirestoreEvent(
                StudentModel.fromMap(c.doc.data()!),
                isRemoved: c.type == DocumentChangeType.removed,
              ))
          .toList());

  // ──────────────────────── الحضور ────────────────────────────────────────────
  Future<void> pushAttendance(AttendanceRecord r) async =>
      _attendanceRef.doc(r.id).set(r.toMap(), SetOptions(merge: true));

  Future<void> pushAttendanceBatch(List<AttendanceRecord> records) async {
    final batch = _db.batch();
    for (final r in records) {
      batch.set(_attendanceRef.doc(r.id), r.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<List<AttendanceRecord>> fetchAllAttendance() async {
    final snap = await _attendanceRef.get();
    return snap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();
  }

  Stream<List<FirestoreEvent<AttendanceRecord>>> watchAttendance() =>
      _attendanceRef.snapshots().map((snap) => snap.docChanges
          .map((c) => FirestoreEvent(
                AttendanceRecord.fromMap(c.doc.data()!),
                isRemoved: c.type == DocumentChangeType.removed,
              ))
          .toList());

  // ──────────────────────── الافتقاد ──────────────────────────────────────────
  Future<List<VisitRecord>> fetchAllVisits() async {
    final snap = await _visitsRef.get();
    return snap.docs.map((d) => VisitRecord.fromMap(d.data())).toList();
  }

  Future<void> pushVisit(VisitRecord v) async =>
      _visitsRef.doc(v.id).set(v.toMap(), SetOptions(merge: true));

  Future<void> pushVisitBatch(List<VisitRecord> visits) async {
    final batch = _db.batch();
    for (final v in visits) {
      batch.set(_visitsRef.doc(v.id), v.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Stream<List<FirestoreEvent<VisitRecord>>> watchVisits() =>
      _visitsRef.snapshots().map((snap) => snap.docChanges
          .map((c) => FirestoreEvent(
                VisitRecord.fromMap(c.doc.data()!),
                isRemoved: c.type == DocumentChangeType.removed,
              ))
          .toList());

  // ──────────────────────── الرحلات ───────────────────────────────────────────
  Future<void> pushTrip(TripModel t) async =>
      _tripsRef.doc(t.id).set(t.toMap(), SetOptions(merge: true));

  Future<void> deleteTrip(String tripId) async {
    await _tripsRef.doc(tripId).delete();
    final bSnap = await _bookingsRef.where('tripId', isEqualTo: tripId).get();
    final batch = _db.batch();
    for (final d in bSnap.docs) batch.delete(d.reference);
    if (bSnap.docs.isNotEmpty) await batch.commit();
  }

  Future<List<TripModel>> fetchAllTrips() async {
    final snap = await _tripsRef.get();
    return snap.docs.map((d) => TripModel.fromMap(d.data())).toList();
  }

  /// stream يحمل الـ docChanges — بيشمل الحذف
  Stream<List<FirestoreEvent<TripModel>>> watchTrips() =>
      _tripsRef.snapshots().map((snap) => snap.docChanges
          .map((c) => FirestoreEvent(
                TripModel.fromMap(c.doc.data()!),
                isRemoved: c.type == DocumentChangeType.removed,
              ))
          .toList());

  // ──────────────────────── حجوزات الرحلات ────────────────────────────────────
  Future<void> pushBooking(TripBooking b) async =>
      _bookingsRef.doc(b.id).set(b.toMap(), SetOptions(merge: true));

  Future<void> deleteBooking(String bookingId) async =>
      _bookingsRef.doc(bookingId).delete();

  Future<List<TripBooking>> fetchAllBookings() async {
    final snap = await _bookingsRef.get();
    return snap.docs.map((d) => TripBooking.fromMap(d.data())).toList();
  }

  Stream<List<FirestoreEvent<TripBooking>>> watchBookings() =>
      _bookingsRef.snapshots().map((snap) => snap.docChanges
          .map((c) => FirestoreEvent(
                TripBooking.fromMap(c.doc.data()!),
                isRemoved: c.type == DocumentChangeType.removed,
              ))
          .toList());

  // ──────────────────────── توزيع الكلمة/اللحن ────────────────────────────────
  Future<void> pushAssignment(ScheduleAssignment a) async =>
      _scheduleRef.doc(a.id).set(a.toMap(), SetOptions(merge: true));

  Future<void> deleteAssignment(String id) async =>
      _scheduleRef.doc(id).delete();

  Future<List<ScheduleAssignment>> fetchAllAssignments() async {
    final snap = await _scheduleRef.get();
    return snap.docs.map((d) => ScheduleAssignment.fromMap(d.data())).toList();
  }

  Stream<List<FirestoreEvent<ScheduleAssignment>>> watchAssignments() =>
      _scheduleRef.snapshots().map((snap) => snap.docChanges
          .map((c) => FirestoreEvent(
                ScheduleAssignment.fromMap(c.doc.data()!),
                isRemoved: c.type == DocumentChangeType.removed,
              ))
          .toList());

  // ──────────────────────── مسح بيانات (admin) ────────────────────────────────
  Future<void> _clearCollection(CollectionReference ref) async {
    const batchSize = 400;
    while (true) {
      final snap = await ref.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) batch.delete(d.reference);
      await batch.commit();
    }
  }

  Future<void> deleteAllAttendance()  => _clearCollection(_attendanceRef);
  Future<void> deleteAllVisits()      => _clearCollection(_visitsRef);
  Future<void> deleteAllTrips()       async {
    await _clearCollection(_tripsRef);
    await _clearCollection(_bookingsRef);
  }
  Future<void> deleteAllSchedule()    => _clearCollection(_scheduleRef);

  // ──────────────────────── إعدادات مشتركة ────────────────────────────────────
  Future<void> pushWhatsappMessage(String message) async {
    await _db.collection(AppConstants.settingsCollection).doc('shared').set(
      {'whatsappMessage': message},
      SetOptions(merge: true),
    );
  }

  Stream<String?> watchWhatsappMessage() {
    return _db
        .collection(AppConstants.settingsCollection)
        .doc('shared')
        .snapshots()
        .map((doc) => doc.data()?['whatsappMessage'] as String?);
  }
}
