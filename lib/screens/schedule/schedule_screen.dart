import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/schedule_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../models/user_model.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await FcmService().requestPermission();
    if (mounted) setState(() => _permissionGranted = granted);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin     = context.watch<AuthProvider>().isAdmin;
    final assignments = context.watch<ScheduleProvider>().allAssignments;
    final words       = assignments.where((a) => a.type == ScheduleType.word).toList();
    final melodies    = assignments.where((a) => a.type == ScheduleType.melody).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('توزيع الكلمة واللحن'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'الكلمة', icon: Icon(Icons.record_voice_over_rounded)),
            Tab(text: 'اللحن',  icon: Icon(Icons.music_note_rounded)),
          ],
        ),
        actions: [
          // أيقونة حالة الإشعارات
          Tooltip(
            message: _permissionGranted
                ? 'الإشعارات مفعّلة'
                : 'اضغط لتفعيل الإشعارات',
            child: IconButton(
              icon: Icon(
                _permissionGranted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: _permissionGranted ? AppColors.present : AppColors.absent,
              ),
              onPressed: () async {
                final ok = await FcmService().requestPermission();
                setState(() => _permissionGranted = ok);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? '✅ تم تفعيل الإشعارات'
                          : '❌ يرجى السماح بالإشعارات من إعدادات الجهاز'),
                    ),
                  );
                }
              },
            ),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'إضافة توزيع',
              onPressed: () => _showAddDialog(context),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _AssignmentList(assignments: words),
          _AssignmentList(assignments: melodies),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final scheduleProv = context.read<ScheduleProvider>();
    final user         = context.read<AuthProvider>().currentUser;

    // جيب قائمة الخدام من Firestore
    List<AppUser> servants = [];
    try {
      servants = await AuthService().getAllServants();
    } catch (_) {}
    if (!context.mounted) return;

    ScheduleType    selectedType     = ScheduleType.word;
    AppUser?        selectedServant  = servants.isNotEmpty ? servants.first : null;
    String          customName       = '';
    DateTime?       activityDate;    // تاريخ الحصة نفسها
    String          selectedActivity = AppConstants.builtinSchedule.first['name'] as String;
    final notesCtrl                  = TextEditingController();

    // متغيرات موعد التذكير
    bool     useHoursMode    = true;  // true = عدد ساعات قبل، false = تاريخ وساعة محدد
    int      reminderHoursVal = 24;
    DateTime? reminderExact;          // لو اختار تاريخ وساعة محددة

    final activities = AppConstants.builtinSchedule.map((b) => b['name'] as String).toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {

          // احسب reminderDateTime الفعلي
          DateTime? computedReminder;
          if (useHoursMode && activityDate != null) {
            computedReminder = activityDate!.subtract(Duration(hours: reminderHoursVal));
          } else if (!useHoursMode && reminderExact != null) {
            computedReminder = reminderExact;
          }

          return AlertDialog(
            title: const Text('إضافة توزيع جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── نوع التوزيع ─────────────────────────────────────────────
                  const Text('النوع:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(children: [
                    Expanded(child: RadioListTile<ScheduleType>(
                      title: const Text('كلمة'),
                      value: ScheduleType.word,
                      groupValue: selectedType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setSt(() => selectedType = v!),
                    )),
                    Expanded(child: RadioListTile<ScheduleType>(
                      title: const Text('لحن'),
                      value: ScheduleType.melody,
                      groupValue: selectedType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setSt(() => selectedType = v!),
                    )),
                  ]),
                  const Divider(),

                  // ── اختيار الخادم ──────────────────────────────────────────
                  const Text('المكلَّف:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (servants.isNotEmpty)
                    DropdownButtonFormField<AppUser>(
                      value: selectedServant,
                      decoration: const InputDecoration(isDense: true),
                      hint: const Text('اختر خادم'),
                      items: [
                        ...servants.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        )),
                        const DropdownMenuItem(value: null, child: Text('اكتب اسم آخر...')),
                      ],
                      onChanged: (v) => setSt(() => selectedServant = v),
                    ),
                  if (selectedServant == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        onChanged: (v) => setSt(() => customName = v.trim()),
                        decoration: const InputDecoration(
                            labelText: 'اسم المكلَّف', isDense: true),
                      ),
                    ),
                  const Divider(),

                  // ── النشاط ──────────────────────────────────────────────────
                  const Text('النشاط:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedActivity,
                    decoration: const InputDecoration(isDense: true),
                    items: activities.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                    onChanged: (v) => setSt(() => selectedActivity = v ?? activities.first),
                  ),
                  const Divider(),

                  // ── تاريخ الحصة ─────────────────────────────────────────────
                  const Text('تاريخ الحصة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                      );
                      if (d != null) setSt(() => activityDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          activityDate == null
                              ? 'اختر تاريخ الحصة *'
                              : '${activityDate!.year}-${activityDate!.month.toString().padLeft(2,'0')}-${activityDate!.day.toString().padLeft(2,'0')}',
                          style: TextStyle(
                            color: activityDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const Divider(),

                  // ── موعد التذكير ─────────────────────────────────────────────
                  const Text('موعد التذكير:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: RadioListTile<bool>(
                      title: const Text('عدد ساعات قبل'),
                      value: true,
                      groupValue: useHoursMode,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setSt(() => useHoursMode = true),
                    )),
                    Expanded(child: RadioListTile<bool>(
                      title: const Text('تاريخ وساعة محددة'),
                      value: false,
                      groupValue: useHoursMode,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setSt(() => useHoursMode = false),
                    )),
                  ]),

                  // ── وضع ساعات ──────────────────────────────────────────────
                  if (useHoursMode) ...[
                    Slider(
                      value: reminderHoursVal.toDouble(),
                      min: 1, max: 168, divisions: 167,
                      label: '${reminderHoursVal == 1 ? "ساعة" : reminderHoursVal == 24 ? "يوم" : reminderHoursVal == 48 ? "يومين" : "$reminderHoursVal ساعة"}',
                      onChanged: (v) => setSt(() => reminderHoursVal = v.round()),
                    ),
                    Text(
                      'التذكير قبل الحصة بـ ${_hoursLabel(reminderHoursVal)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (computedReminder != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '📅 سيُرسل الإشعار: ${_formatDateTime(computedReminder!)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.present),
                        ),
                      ),
                  ],

                  // ── وضع تاريخ وساعة محددة ─────────────────────────────────
                  if (!useHoursMode) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: activityDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: activityDate ?? DateTime.now().add(const Duration(days: 180)),
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (t != null) {
                          setSt(() => reminderExact = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            reminderExact == null
                                ? 'اختر تاريخ وساعة التذكير *'
                                : '📅 ${_formatDateTime(reminderExact!)}',
                            style: TextStyle(
                              color: reminderExact == null ? AppColors.textSecondary : AppColors.present,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                  const Divider(),

                  // ── ملاحظات ──────────────────────────────────────────────────
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)', isDense: true),
                  ),

                  // ── تحذير الإشعارات ──────────────────────────────────────────
                  if (!_permissionGranted)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.absent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.absent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.warning_outlined, color: AppColors.absent, size: 16),
                        SizedBox(width: 6),
                        Expanded(child: Text(
                          'الإشعارات مش مفعّلة! فعّلها من الزر في الأعلى عشان الإشعار يوصل.',
                          style: TextStyle(fontSize: 11, color: AppColors.absent),
                        )),
                      ]),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                  onPressed: computedReminder == null
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('إضافة')),
            ],
          );
        },
      ),
    );

    if (result != true || !context.mounted) return;

    // تحديد اسم ورقم UID المكلّف
    final assigneeName = selectedServant?.name ?? customName;
    final assigneeUid  = selectedServant?.uid  ?? '';

    if (assigneeName.isEmpty || activityDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اسم المكلَّف وتاريخ الحصة مطلوبين')));
      return;
    }

    // احسب reminderDateTime النهائي
    late DateTime finalReminder;
    if (useHoursMode) {
      finalReminder = activityDate!.subtract(Duration(hours: reminderHoursVal));
    } else {
      finalReminder = reminderExact!;
    }

    final dateKey =
        '${activityDate!.year}-${activityDate!.month.toString().padLeft(2,'0')}-${activityDate!.day.toString().padLeft(2,'0')}';

    await scheduleProv.addAssignment(
      dateKey:          dateKey,
      type:             selectedType,
      assigneeName:     assigneeName,
      assigneeUid:      assigneeUid,
      activityName:     selectedActivity,
      notes:            notesCtrl.text.trim(),
      reminderDateTime: finalReminder,
      createdBy:        user?.name ?? '',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '✅ تم توزيع ${scheduleTypeLabel(selectedType)} على $assigneeName\n'
          '🔔 إشعار تذكير: ${_formatDateTime(finalReminder)}',
        ),
      ));
    }
  }

  String _hoursLabel(int h) {
    if (h == 1)  return 'ساعة واحدة';
    if (h == 24) return 'يوم كامل';
    if (h == 48) return 'يومين';
    if (h % 24 == 0) return '${h ~/ 24} أيام';
    return '$h ساعة';
  }

  String _formatDateTime(DateTime dt) {
    final day  = dt.day.toString().padLeft(2, '0');
    final mon  = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min  = dt.minute.toString().padLeft(2, '0');
    return '$day/$mon/${dt.year} الساعة $hour:$min';
  }
}

// ── قائمة التوزيعات ────────────────────────────────────────────────────────
class _AssignmentList extends StatelessWidget {
  final List<ScheduleAssignment> assignments;
  const _AssignmentList({required this.assignments});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    if (assignments.isEmpty) {
      return const Center(
        child: Text('مفيش توزيعات مضافة',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: assignments.length,
      itemBuilder: (ctx, i) {
        final a      = assignments[i];
        final isPast = a.reminderDateTime.isBefore(DateTime.now());

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: a.type == ScheduleType.word
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.secondary.withValues(alpha: 0.15),
              child: Icon(
                a.type == ScheduleType.word
                    ? Icons.record_voice_over_rounded
                    : Icons.music_note_rounded,
                color: a.type == ScheduleType.word
                    ? AppColors.primary
                    : AppColors.secondary,
              ),
            ),
            title: Text(a.assigneeName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.activityName} — ${a.dateKey}',
                    style: const TextStyle(fontSize: 12)),
                if (a.notes.isNotEmpty)
                  Text(a.notes,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                Row(children: [
                  Icon(
                    isPast
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_outlined,
                    size: 13,
                    color: isPast ? AppColors.present : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '🔔 ${_fmt(a.reminderDateTime)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ]),
              ],
            ),
            isThreeLine: true,
            trailing: isAdmin
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.absent),
                    tooltip: 'حذف',
                    onPressed: () => _confirmDelete(ctx, a),
                  )
                : (isPast
                    ? const Icon(Icons.check_circle_outline, color: AppColors.present)
                    : null),
          ),
        );
      },
    );
  }

  String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2,'0');
    final m = dt.month.toString().padLeft(2,'0');
    final h = dt.hour.toString().padLeft(2,'0');
    final mi= dt.minute.toString().padLeft(2,'0');
    return '$d/$m/${dt.year} $h:$mi';
  }

  Future<void> _confirmDelete(BuildContext context, ScheduleAssignment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التوزيع'),
        content: Text('هتحذف توزيع ${scheduleTypeLabel(a.type)} لـ ${a.assigneeName} نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('احذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ScheduleProvider>().deleteAssignment(a.id);
    }
  }
}
