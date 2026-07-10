import 'package:hive/hive.dart';

enum ScheduleType { word, melody }

String scheduleTypeToString(ScheduleType t) =>
    t == ScheduleType.word ? 'word' : 'melody';

ScheduleType scheduleTypeFromString(String s) =>
    s == 'word' ? ScheduleType.word : ScheduleType.melody;

String scheduleTypeLabel(ScheduleType t) =>
    t == ScheduleType.word ? 'الكلمة' : 'اللحن';

/// نموذج توزيع كلمة أو لحن لخادم معين في تاريخ معين
class ScheduleAssignment {
  final String       id;
  String             dateKey;           // yyyy-MM-dd — يوم الحصة/النشاط
  ScheduleType       type;              // word أو melody
  String             assigneeName;      // اسم الخادم/المدير المكلَّف
  String             assigneeUid;       // uid الخادم (للإشعار الحقيقي)
  String             activityName;      // اسم النشاط
  String             notes;
  int                reminderHours;     // محتفظ به للتوافق مع البيانات القديمة
  DateTime           reminderDateTime;  // التاريخ والوقت الفعلي للتذكير
  bool               reminderSent;
  String             createdBy;
  final DateTime     createdAt;
  DateTime           updatedAt;
  bool               isDeleted;

  ScheduleAssignment({
    required this.id,
    required this.dateKey,
    required this.type,
    required this.assigneeName,
    this.assigneeUid    = '',
    required this.activityName,
    this.notes          = '',
    this.reminderHours  = 24,
    DateTime?          reminderDateTime,
    this.reminderSent   = false,
    this.createdBy      = '',
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted      = false,
  }) : reminderDateTime = reminderDateTime ??
           DateTime.now().subtract(const Duration(seconds: 1));

  ScheduleAssignment copyWith({
    String?       dateKey,
    ScheduleType? type,
    String?       assigneeName,
    String?       assigneeUid,
    String?       activityName,
    String?       notes,
    int?          reminderHours,
    DateTime?     reminderDateTime,
    bool?         reminderSent,
    DateTime?     updatedAt,
    bool?         isDeleted,
  }) {
    return ScheduleAssignment(
      id:               id,
      dateKey:          dateKey          ?? this.dateKey,
      type:             type             ?? this.type,
      assigneeName:     assigneeName     ?? this.assigneeName,
      assigneeUid:      assigneeUid      ?? this.assigneeUid,
      activityName:     activityName     ?? this.activityName,
      notes:            notes            ?? this.notes,
      reminderHours:    reminderHours    ?? this.reminderHours,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
      reminderSent:     reminderSent     ?? this.reminderSent,
      createdBy:        createdBy,
      createdAt:        createdAt,
      updatedAt:        updatedAt        ?? this.updatedAt,
      isDeleted:        isDeleted        ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id':               id,
        'dateKey':          dateKey,
        'type':             scheduleTypeToString(type),
        'assigneeName':     assigneeName,
        'assigneeUid':      assigneeUid,
        'activityName':     activityName,
        'notes':            notes,
        'reminderHours':    reminderHours,
        'reminderDateTime': reminderDateTime.millisecondsSinceEpoch,
        'reminderSent':     reminderSent,
        'createdBy':        createdBy,
        'createdAt':        createdAt.millisecondsSinceEpoch,
        'updatedAt':        updatedAt.millisecondsSinceEpoch,
        'isDeleted':        isDeleted,
      };

  factory ScheduleAssignment.fromMap(Map<String, dynamic> m) {
    final rdMs = m['reminderDateTime'] as int?;
    return ScheduleAssignment(
      id:               m['id'] as String,
      dateKey:          m['dateKey'] as String,
      type:             scheduleTypeFromString((m['type'] as String?) ?? 'word'),
      assigneeName:     (m['assigneeName'] as String?) ?? '',
      assigneeUid:      (m['assigneeUid'] as String?) ?? '',
      activityName:     (m['activityName'] as String?) ?? '',
      notes:            (m['notes'] as String?) ?? '',
      reminderHours:    (m['reminderHours'] as int?) ?? 24,
      reminderDateTime: rdMs != null
          ? DateTime.fromMillisecondsSinceEpoch(rdMs)
          : null,
      reminderSent:     (m['reminderSent'] as bool?) ?? false,
      createdBy:        (m['createdBy'] as String?) ?? '',
      createdAt:        DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      updatedAt:        DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
      isDeleted:        (m['isDeleted'] as bool?) ?? false,
    );
  }
}

class ScheduleAssignmentAdapter extends TypeAdapter<ScheduleAssignment> {
  @override
  final int typeId = 6;

  @override
  ScheduleAssignment read(BinaryReader reader) {
    final m = reader.readMap();
    final rdMs = m['reminderDateTime'] as int?;
    return ScheduleAssignment(
      id:               m['id'] as String,
      dateKey:          m['dateKey'] as String,
      type:             scheduleTypeFromString((m['type'] as String?) ?? 'word'),
      assigneeName:     (m['assigneeName'] as String?) ?? '',
      assigneeUid:      (m['assigneeUid'] as String?) ?? '',
      activityName:     (m['activityName'] as String?) ?? '',
      notes:            (m['notes'] as String?) ?? '',
      reminderHours:    (m['reminderHours'] as int?) ?? 24,
      reminderDateTime: rdMs != null
          ? DateTime.fromMillisecondsSinceEpoch(rdMs)
          : null,
      reminderSent:     (m['reminderSent'] as bool?) ?? false,
      createdBy:        (m['createdBy'] as String?) ?? '',
      createdAt:        DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      updatedAt:        DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
      isDeleted:        (m['isDeleted'] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleAssignment obj) {
    writer.writeMap({
      'id':               obj.id,
      'dateKey':          obj.dateKey,
      'type':             scheduleTypeToString(obj.type),
      'assigneeName':     obj.assigneeName,
      'assigneeUid':      obj.assigneeUid,
      'activityName':     obj.activityName,
      'notes':            obj.notes,
      'reminderHours':    obj.reminderHours,
      'reminderDateTime': obj.reminderDateTime.millisecondsSinceEpoch,
      'reminderSent':     obj.reminderSent,
      'createdBy':        obj.createdBy,
      'createdAt':        obj.createdAt.millisecondsSinceEpoch,
      'updatedAt':        obj.updatedAt.millisecondsSinceEpoch,
      'isDeleted':        obj.isDeleted,
    });
  }
}
