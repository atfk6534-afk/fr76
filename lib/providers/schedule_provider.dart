import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_model.dart';
import '../services/local_db_service.dart';
import '../services/firestore_service.dart';
import '../services/fcm_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final LocalDbService   _local;
  final FirestoreService _remote;
  final FcmService       _fcm;
  static const _uuid = Uuid();

  ScheduleProvider(this._local, this._remote, this._fcm);

  List<ScheduleAssignment> get allAssignments => _local.getAllAssignments();

  List<ScheduleAssignment> getForDate(String dateKey) =>
      _local.getAssignmentsForDate(dateKey);

  Future<void> addAssignment({
    required String       dateKey,
    required ScheduleType type,
    required String       assigneeName,
    required String       assigneeUid,
    required String       activityName,
    required String       notes,
    required DateTime     reminderDateTime,
    required String       createdBy,
  }) async {
    final now        = DateTime.now();
    final assignment = ScheduleAssignment(
      id:              _uuid.v4(),
      dateKey:         dateKey,
      type:            type,
      assigneeName:    assigneeName,
      assigneeUid:     assigneeUid,
      activityName:    activityName,
      notes:           notes,
      reminderDateTime: reminderDateTime,
      createdBy:       createdBy,
      createdAt:       now,
      updatedAt:       now,
    );

    // محلياً
    await _local.saveAssignment(assignment);
    notifyListeners();

    // Firestore — يوصل للخدام التانيين عبر real-time stream
    try { await _remote.pushAssignment(assignment); } catch (_) {}

    // إشعار FCM مجدوَل (Cloud Function تبعته في الوقت الصح)
    if (assigneeUid.isNotEmpty) {
      try {
        await _fcm.sendScheduleNotification(
          toUid:        assigneeUid,
          assigneeName: assigneeName,
          typeLabel:    scheduleTypeLabel(type),
          activityName: activityName,
          dateKey:      dateKey,
          reminderTime: reminderDateTime,
          assignmentId: assignment.id,
        );
      } catch (_) {}
    }
  }

  Future<void> updateAssignment(
      ScheduleAssignment a, DateTime newReminderDateTime) async {
    // ألغِ الإشعار القديم
    try { await _fcm.cancelScheduleNotification(a.id); } catch (_) {}

    final updated = a.copyWith(
      updatedAt:        DateTime.now(),
      reminderSent:     false,
      reminderDateTime: newReminderDateTime,
    );
    await _local.saveAssignment(updated);
    notifyListeners();
    try { await _remote.pushAssignment(updated); } catch (_) {}

    // جدول الإشعار الجديد
    if (a.assigneeUid.isNotEmpty) {
      try {
        await _fcm.sendScheduleNotification(
          toUid:        a.assigneeUid,
          assigneeName: a.assigneeName,
          typeLabel:    scheduleTypeLabel(a.type),
          activityName: a.activityName,
          dateKey:      a.dateKey,
          reminderTime: newReminderDateTime,
          assignmentId: a.id,
        );
      } catch (_) {}
    }
  }

  /// حذف نهائي — يحذف الإشعار المعلّق كمان
  Future<void> deleteAssignment(String id) async {
    try { await _fcm.cancelScheduleNotification(id); } catch (_) {}
    await _local.hardDeleteAssignment(id);
    notifyListeners();
    try { await _remote.deleteAssignment(id); } catch (_) {}
  }
}
