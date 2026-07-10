import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/visit_model.dart';
import '../models/trip_model.dart';
import '../models/schedule_model.dart';
import 'local_db_service.dart';
import 'firestore_service.dart';
import 'connectivity_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SyncService
///
/// القواعد الصارمة:
///  • Firestore هي المصدر الوحيد للحقيقة
///  • لما Firestore يحذف document → يُحذف من Hive نهائياً (hardDelete)
///  • لا تُرفع بيانات محلية قبل اكتمال السحب الأولي
///  • الـ streams تعمل على docChanges — تشمل added / modified / removed
/// ─────────────────────────────────────────────────────────────────────────────
class SyncService {
  final LocalDbService      _local;
  final FirestoreService    _remote;
  final ConnectivityService _connectivity;

  StreamSubscription? _studentsSub;
  StreamSubscription? _attendanceSub;
  StreamSubscription? _visitsSub;
  StreamSubscription? _tripsSub;
  StreamSubscription? _bookingsSub;
  StreamSubscription? _scheduleSub;
  StreamSubscription<bool>? _connectivitySub;

  bool _initialSyncDone = false;
  bool _isSyncing       = false;

  final _onDataChanged = StreamController<void>.broadcast();
  Stream<void> get onDataChanged => _onDataChanged.stream;

  SyncService(this._local, this._remote, this._connectivity);

  // ─── السحب الأولي الكامل من Firestore ──────────────────────────────────────
  Future<void> performInitialSync() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (!await _connectivity.isOnline()) {
      _initialSyncDone = true;
      return;
    }
    try {
      await _downloadAll();
      await _pushPending();
    } catch (_) {}
    _initialSyncDone = true;
    _startStreams();
    _watchConnectivity();
  }

  Future<void> _downloadAll() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    bool changed = false;

    // الشباب
    for (final r in await _remote.fetchAllStudents()) {
      final local = _local.getStudent(r.id);
      if (local == null || (!local.needsSync && r.updatedAt.isAfter(local.updatedAt))) {
        await _local.saveStudent(r.copyWith(needsSync: false));
        changed = true;
      }
    }

    // الحضور
    for (final r in await _remote.fetchAllAttendance()) {
      final localList = _local.getAttendanceForStudent(r.studentId);
      final local     = localList.where((l) => l.id == r.id).firstOrNull;
      if (local == null || (!local.needsSync && r.updatedAt.isAfter(local.updatedAt))) {
        await _local.saveAttendanceRecord(r.copyWith(needsSync: false));
        changed = true;
      }
    }

    // الافتقاد
    for (final r in await _remote.fetchAllVisits()) {
      final local = _local.getVisit(r.id);
      if (local == null || (!local.needsSync && r.updatedAt.isAfter(local.updatedAt))) {
        await _local.saveVisit(r.copyWith(needsSync: false));
        changed = true;
      }
    }

    // الرحلات — الحذف من Firestore = غير موجود في النتيجة = محذوف من Hive
    final remoteTrips = await _remote.fetchAllTrips();
    final remoteTripIds = remoteTrips.map((t) => t.id).toSet();
    for (final r in remoteTrips) {
      final local = _local.getTrip(r.id);
      if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
        await _local.saveTrip(r);
        changed = true;
      }
    }
    // حذف أي رحلة موجودة محلياً لكن مش موجودة في Firestore
    for (final local in _local.getAllTrips(includeDeleted: true)) {
      if (!remoteTripIds.contains(local.id)) {
        await _local.hardDeleteTrip(local.id);
        changed = true;
      }
    }

    // حجوزات الرحلات
    final remoteBookings = await _remote.fetchAllBookings();
    final remoteBookingIds = remoteBookings.map((b) => b.id).toSet();
    for (final r in remoteBookings) {
      final local = _local.getBooking(r.id);
      if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
        await _local.saveBooking(r);
        changed = true;
      }
    }
    for (final local in _local.getAllBookings()) {
      if (!remoteBookingIds.contains(local.id)) {
        await _local.hardDeleteBooking(local.id);
        changed = true;
      }
    }

    // التوزيع
    final remoteAssignments = await _remote.fetchAllAssignments();
    final remoteAssignIds   = remoteAssignments.map((a) => a.id).toSet();
    for (final r in remoteAssignments) {
      final localList = _local.getAllAssignments(includeDeleted: true);
      final local     = localList.where((l) => l.id == r.id).firstOrNull;
      if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
        await _local.saveAssignment(r);
        changed = true;
      }
    }
    for (final local in _local.getAllAssignments(includeDeleted: true)) {
      if (!remoteAssignIds.contains(local.id)) {
        await _local.hardDeleteAssignment(local.id);
        changed = true;
      }
    }

    if (changed) _onDataChanged.add(null);
  }

  // ─── رفع التغييرات المعلقة ──────────────────────────────────────────────────
  Future<void> _pushPending() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (!await _connectivity.isOnline()) return;
    if (_local.getAllStudents(includeDeleted: true).isEmpty) return;
    for (final s in _local.getStudentsNeedingSync()) {
      try {
        await _remote.pushStudent(s);
        await _local.saveStudent(s.copyWith(needsSync: false));
      } catch (_) {}
    }
    final att = _local.getAttendanceNeedingSync();
    if (att.isNotEmpty) {
      try {
        await _remote.pushAttendanceBatch(att);
        await _local.saveAttendanceBatch(att.map((r) => r.copyWith(needsSync: false)).toList());
      } catch (_) {}
    }
    for (final v in _local.getVisitsNeedingSync()) {
      try {
        await _remote.pushVisit(v);
        await _local.saveVisit(v.copyWith(needsSync: false));
      } catch (_) {}
    }
  }

  Future<void> syncNow() async {
    if (!_initialSyncDone || _isSyncing) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    _isSyncing = true;
    try {
      if (await _connectivity.isOnline()) await _pushPending();
    } finally {
      _isSyncing = false;
    }
  }

  // ─── Real-time streams (docChanges — يشمل الحذف) ───────────────────────────
  void _startStreams() {
    _cancelStreams();

    _studentsSub = _remote.watchStudents().listen((events) async {
      if (!_initialSyncDone) return;
      bool ch = false;
      for (final e in events) {
        if (e.isRemoved) {
          await _local.hardDeleteStudent(e.data.id);
        } else {
          final local = _local.getStudent(e.data.id);
          if (local == null || (!local.needsSync && e.data.updatedAt.isAfter(local.updatedAt))) {
            await _local.saveStudent(e.data.copyWith(needsSync: false));
          }
        }
        ch = true;
      }
      if (ch) _onDataChanged.add(null);
    });

    _attendanceSub = _remote.watchAttendance().listen((events) async {
      if (!_initialSyncDone) return;
      bool ch = false;
      for (final e in events) {
        if (e.isRemoved) {
          await _local.hardDeleteAttendance(e.data.id);
        } else {
          final localList = _local.getAttendanceForStudent(e.data.studentId);
          final local     = localList.where((l) => l.id == e.data.id).firstOrNull;
          if (local == null || (!local.needsSync && e.data.updatedAt.isAfter(local.updatedAt))) {
            await _local.saveAttendanceRecord(e.data.copyWith(needsSync: false));
          }
        }
        ch = true;
      }
      if (ch) _onDataChanged.add(null);
    });

    _visitsSub = _remote.watchVisits().listen((events) async {
      if (!_initialSyncDone) return;
      bool ch = false;
      for (final e in events) {
        if (e.isRemoved) {
          await _local.hardDeleteVisit(e.data.id);
        } else {
          final local = _local.getVisit(e.data.id);
          if (local == null || (!local.needsSync && e.data.updatedAt.isAfter(local.updatedAt))) {
            await _local.saveVisit(e.data.copyWith(needsSync: false));
          }
        }
        ch = true;
      }
      if (ch) _onDataChanged.add(null);
    });

    _tripsSub = _remote.watchTrips().listen((events) async {
      if (!_initialSyncDone) return;
      bool ch = false;
      for (final e in events) {
        if (e.isRemoved) {
          await _local.hardDeleteTrip(e.data.id);
        } else {
          final local = _local.getTrip(e.data.id);
          if (local == null || e.data.updatedAt.isAfter(local.updatedAt)) {
            await _local.saveTrip(e.data);
          }
        }
        ch = true;
      }
      if (ch) _onDataChanged.add(null);
    });

    _bookingsSub = _remote.watchBookings().listen((events) async {
      if (!_initialSyncDone) return;
      bool ch = false;
      for (final e in events) {
        if (e.isRemoved) {
          await _local.hardDeleteBooking(e.data.id);
        } else {
          final local = _local.getBooking(e.data.id);
          if (local == null || e.data.updatedAt.isAfter(local.updatedAt)) {
            await _local.saveBooking(e.data);
          }
        }
        ch = true;
      }
      if (ch) _onDataChanged.add(null);
    });

    _scheduleSub = _remote.watchAssignments().listen((events) async {
      if (!_initialSyncDone) return;
      bool ch = false;
      for (final e in events) {
        if (e.isRemoved) {
          await _local.hardDeleteAssignment(e.data.id);
        } else {
          final localList = _local.getAllAssignments(includeDeleted: true);
          final local     = localList.where((l) => l.id == e.data.id).firstOrNull;
          if (local == null || e.data.updatedAt.isAfter(local.updatedAt)) {
            await _local.saveAssignment(e.data);
          }
        }
        ch = true;
      }
      if (ch) _onDataChanged.add(null);
    });
  }

  void _watchConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onStatusChange.listen((online) async {
      if (online && _initialSyncDone) {
        await _pushPending();
        _startStreams();
      } else if (!online) {
        _cancelStreams();
      }
    });
  }

  void _cancelStreams() {
    _studentsSub?.cancel();
    _attendanceSub?.cancel();
    _visitsSub?.cancel();
    _tripsSub?.cancel();
    _bookingsSub?.cancel();
    _scheduleSub?.cancel();
  }

  void stopListeners() {
    _cancelStreams();
    _connectivitySub?.cancel();
    _initialSyncDone = false;
  }

  void dispose() {
    stopListeners();
    _onDataChanged.close();
  }
}
