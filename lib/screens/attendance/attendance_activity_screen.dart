import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_helper.dart';
import '../../models/student_model.dart';

class AttendanceActivityScreen extends StatefulWidget {
  final DateTime date;
  final String activity;

  const AttendanceActivityScreen(
      {super.key, required this.date, required this.activity});

  @override
  State<AttendanceActivityScreen> createState() =>
      _AttendanceActivityScreenState();
}

class _AttendanceActivityScreenState extends State<AttendanceActivityScreen> {
  late Map<String, bool> _presence;
  late Map<String, String> _notes;
  bool _isSaving = false;
  bool _initialized = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _editNote(String studentId, String studentName) async {
    final controller = TextEditingController(text: _notes[studentId] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ملاحظة حضور $studentName'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ملاحظة اختيارية...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _notes[studentId] = result.trim());
    }
  }

  // تحديد الكل / إلغاء الكل للنتائج المرئية
  void _toggleAll(List<StudentModel> visible, bool value) {
    setState(() {
      for (final s in visible) {
        _presence[s.id] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendancePro = context.watch<AttendanceProvider>();
    final allStudents   = context.watch<StudentProvider>().allStudents;
    final activityPoints = AppConstants.pointsForActivity(widget.activity);

    // تهيئة الخريطة مرة واحدة
    if (!_initialized) {
      final existing =
          attendancePro.getAttendanceMap(widget.date, widget.activity);
      _presence = {for (final s in allStudents) s.id: existing[s.id] ?? false};
      _notes = {};
      _initialized = true;
    }

    // فلترة حسب البحث
    final filtered = _query.trim().isEmpty
        ? allStudents
        : allStudents
            .where((s) =>
                s.fullName.contains(_query) ||
                s.firstName.contains(_query))
            .toList();

    final presentCount =
        _presence.values.where((v) => v).length;
    final totalCount   = allStudents.length;
    final absentCount  = totalCount - presentCount;
    final percentage   =
        totalCount == 0 ? 0.0 : (presentCount / totalCount) * 100;

    // هل كل المرئيين محددين؟
    final allVisiblePresent = filtered.isNotEmpty &&
        filtered.every((s) => _presence[s.id] == true);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'بحث باسم الشاب...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                        }),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── ملخص الإحصائيات ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                children: [
                  Text(
                    DateHelper.displayDateWithDay(widget.date),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (activityPoints > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'نقاط الحضور: $activityPoints نقطة',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _miniStat('حضور', '$presentCount', AppColors.present),
                      _miniStat('غياب', '$absentCount', AppColors.absent),
                      _miniStat('النسبة',
                          '${percentage.toStringAsFixed(0)}%', AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),

            // ─── شريط تحديد الكل ────────────────────────────────────
            if (filtered.isNotEmpty)
              Container(
                color: AppColors.primary.withValues(alpha: 0.06),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _query.isEmpty
                          ? 'الكل (${filtered.length})'
                          : 'نتائج: ${filtered.length}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _toggleAll(filtered, true),
                      icon: const Icon(Icons.check_box_rounded,
                          size: 18, color: AppColors.present),
                      label: const Text('تحديد الكل',
                          style: TextStyle(color: AppColors.present)),
                    ),
                    TextButton.icon(
                      onPressed: () => _toggleAll(filtered, false),
                      icon: const Icon(Icons.check_box_outline_blank,
                          size: 18, color: AppColors.absent),
                      label: const Text('إلغاء الكل',
                          style: TextStyle(color: AppColors.absent)),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // ─── قائمة الشباب ────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.isNotEmpty
                            ? 'لا توجد نتائج للبحث'
                            : 'لا يوجد شباب مسجلين بعد',
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final student   = filtered[index];
                        final isPresent = _presence[student.id] ?? false;
                        final hasNote =
                            (_notes[student.id] ?? '').isNotEmpty;
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isPresent
                                    ? AppColors.present
                                    : AppColors.absent)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isPresent
                                      ? AppColors.present
                                      : AppColors.absent)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isPresent,
                            onChanged: (value) {
                              setState(() =>
                                  _presence[student.id] = value ?? false);
                            },
                            activeColor: AppColors.present,
                            title: Text(student.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: isPresent && activityPoints > 0
                                ? Text('+$activityPoints نقطة',
                                    style: const TextStyle(
                                        color: AppColors.present,
                                        fontSize: 12))
                                : null,
                            secondary: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    hasNote
                                        ? Icons.edit_note
                                        : Icons.note_add_outlined,
                                    color: hasNote
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  tooltip: 'ملاحظة',
                                  onPressed: () => _editNote(
                                      student.id, student.fullName),
                                ),
                                Icon(
                                  isPresent
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: isPresent
                                      ? AppColors.present
                                      : AppColors.absent,
                                ),
                              ],
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('حفظ الحضور'),
              onPressed: allStudents.isEmpty || _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      await context.read<AttendanceProvider>().saveAttendance(
                            date: widget.date,
                            activity: widget.activity,
                            studentPresence: _presence,
                            notes: _notes,
                          );
                      if (mounted) {
                        setState(() => _isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تم حفظ الحضور بنجاح ✓')),
                        );
                        Navigator.pop(context);
                      }
                    },
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
