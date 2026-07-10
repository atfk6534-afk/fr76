import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/student_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/visit_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../widgets/stat_card.dart';
import '../../models/student_model.dart';
import 'add_edit_student_screen.dart';

class StudentDetailsScreen extends StatelessWidget {
  final String studentId;
  const StudentDetailsScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final studentPro  = context.watch<StudentProvider>();
    final attendPro   = context.watch<AttendanceProvider>();
    final student     = studentPro.getById(studentId);

    if (student == null) {
      return const Scaffold(body: Center(child: Text('هذا الشاب غير موجود')));
    }

    final stats        = attendPro.studentStats(studentId);
    final points       = attendPro.totalPoints(studentId);
    final lastAtt      = attendPro.lastAttendance(studentId);
    final records      = attendPro.getAttendanceForStudent(studentId);
    final adjustments  = attendPro.getAdjustmentsForStudent(studentId);

    // تجميع حسب التاريخ
    final Map<String, List<dynamic>> byDate = {};
    for (final r in records) {
      byDate.putIfAbsent(r.dateKey, () => []).add(r);
    }
    final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(student.firstName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'تعديل البيانات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditStudentScreen(student: student),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_off_rounded),
            tooltip: 'الافتقاد',
            onPressed: () => _openVisitSheet(context,
                studentId: studentId, studentName: student.fullName),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ─── البطاقة الشخصية الكاملة ────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الاسم + نقاط
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            student.firstName.isNotEmpty
                                ? student.firstName[0]
                                : '؟',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.fullName,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '🏆 $points نقطة',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // ─── التفاصيل ───────────────────────────────────
                    _infoRow(
                      Icons.phone_android,
                      'واتساب',
                      student.phone.isNotEmpty ? student.phone : '—',
                      onTap: student.phone.isNotEmpty
                          ? () => _callPhone(context, student.phone)
                          : null,
                      onLongPress: student.phone.isNotEmpty
                          ? () => _copyToClipboard(context, student.phone)
                          : null,
                    ),

                    if (student.phone2.isNotEmpty)
                      _infoRow(
                        Icons.phone,
                        'تليفون ٢',
                        student.phone2,
                        onTap: () => _callPhone(context, student.phone2),
                        onLongPress: () =>
                            _copyToClipboard(context, student.phone2),
                      ),

                    if (student.birthDate.isNotEmpty)
                      _infoRow(
                          Icons.cake_outlined, 'تاريخ الميلاد', student.birthDate),

                    if (student.address.isNotEmpty)
                      _infoRow(Icons.location_on_outlined, 'العنوان',
                          student.address),

                    if (student.addressDetail.isNotEmpty)
                      _infoRow(Icons.signpost_outlined, 'العنوان التفصيلي',
                          student.addressDetail),

                    if (lastAtt != null)
                      _infoRow(
                        Icons.event_available,
                        'آخر حضور',
                        DateHelper.displayDateWithDay(
                            DateHelper.fromKey(lastAtt.dateKey)),
                      ),

                    if (student.notes.isNotEmpty)
                      _infoRow(Icons.notes_rounded, 'ملاحظات', student.notes),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─── أزرار الإجراءات ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openVisitSheet(context,
                        studentId: studentId, studentName: student.fullName),
                    icon: const Icon(Icons.search_off_rounded, size: 18),
                    label: const Text('افتقاد'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: student.phone.isNotEmpty
                        ? () => _sendVisitMessage(context, student: student)
                        : null,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('رسالة واتساب'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── إحصائيات ────────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                StatCard(
                  title: 'مجموع النقاط',
                  value: '$points',
                  icon: Icons.stars_rounded,
                  color: AppColors.warning,
                ),
                StatCard(
                  title: 'نسبة الالتزام',
                  value: '${stats.percentage.toStringAsFixed(0)}%',
                  icon: Icons.percent,
                  color: AppColors.primary,
                ),
                StatCard(
                  title: 'مرات الحضور',
                  value: '${stats.present}',
                  icon: Icons.check_circle,
                  color: AppColors.present,
                ),
                StatCard(
                  title: 'مرات الغياب',
                  value: '${stats.absent}',
                  icon: Icons.cancel,
                  color: AppColors.absent,
                ),
              ],
            ),

            // ─── تعديلات النقاط اليدوية ───────────────────────────────
            if (adjustments.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('تعديلات النقاط اليدوية',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...adjustments.map((a) => ListTile(
                    dense: true,
                    leading: Icon(
                      a.delta >= 0 ? Icons.add_circle : Icons.remove_circle,
                      color: a.delta >= 0 ? AppColors.present : AppColors.absent,
                      size: 20,
                    ),
                    title: Text(
                        '${a.delta >= 0 ? '+' : ''}${a.delta} نقطة'
                        '${a.reason.isNotEmpty ? '  •  ${a.reason}' : ''}'),
                    subtitle: Text(
                        '${DateHelper.displayDate(DateHelper.fromKey(a.dateKey))}'
                        '${a.createdBy.isNotEmpty ? '  —  ${a.createdBy}' : ''}'),
                  )),
            ],

            // ─── سجل الحضور ──────────────────────────────────────────
            const SizedBox(height: 20),
            const Text('سجل الحضور',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (sortedDates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('لا يوجد سجل حضور بعد')),
              )
            else
              ...sortedDates.map((dateKey) {
                final dayRecs = byDate[dateKey]!;
                final dayPresent = dayRecs.where((r) => r.isPresent).length;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateHelper.displayDateWithDay(
                                    DateHelper.fromKey(dateKey)),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              '$dayPresent/${dayRecs.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dayPresent > 0
                                    ? AppColors.present
                                    : AppColors.absent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...dayRecs.map((r) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    r.isPresent
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 18,
                                    color: r.isPresent
                                        ? AppColors.present
                                        : AppColors.absent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r.isPresent ? "حضر" : "غاب"} ${r.activity}'
                                          '${r.isPresent ? " (+${r.points} نقطة)" : ""}',
                                        ),
                                        if (r.note.isNotEmpty)
                                          Text(
                                            r.note,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─── مساعدات UI ──────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String label, String value,
      {VoidCallback? onTap, VoidCallback? onLongPress}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Text(value,
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _callPhone(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ $text')),
    );
  }

  void _sendVisitMessage(BuildContext context, {required StudentModel student}) async {
    final msg  = context.read<SettingsProvider>().whatsappMessage;
    final text = WhatsappHelper.buildMessage(msg, student.firstName);
    final ok   = await WhatsappHelper.openWhatsapp(phone: student.phone, message: text);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }

  void _openVisitSheet(BuildContext context,
      {required String studentId, required String studentName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _VisitSheet(studentId: studentId, studentName: studentName),
    );
  }
}

// ─── شيت الافتقاد ────────────────────────────────────────────────────────────

class _VisitSheet extends StatefulWidget {
  final String studentId;
  final String studentName;
  const _VisitSheet({required this.studentId, required this.studentName});

  @override
  State<_VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends State<_VisitSheet> {
  final _noteCtrl = TextEditingController();
  bool _isSaving  = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    await context.read<VisitProvider>().addVisit(
          studentId: widget.studentId,
          note: _noteCtrl.text,
          createdBy: auth.currentUser?.name ?? '',
        );
    _noteCtrl.clear();
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final attendPro = context.watch<AttendanceProvider>();
    final visitPro  = context.watch<VisitProvider>();

    final isAbsentToday = attendPro.isAbsentToday(widget.studentId);
    final absentDays    = attendPro.absentDaysCount(widget.studentId);
    final lastAtt       = attendPro.lastAttendance(widget.studentId);
    final missing       = attendPro.missingCategories(widget.studentId);
    final absenceLog    = attendPro.absenceLog(widget.studentId);
    final visits        = visitPro.getVisitsForStudent(widget.studentId);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Text('افتقاد ${widget.studentName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ملخص الغياب
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isAbsentToday ? AppColors.absent : AppColors.present)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      isAbsentToday ? Icons.cancel : Icons.check_circle,
                      color: isAbsentToday ? AppColors.absent : AppColors.present,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAbsentToday ? 'غائب اليوم' : 'غير مسجل غياب اليوم',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('عدد أيام الغياب: $absentDays يوم'),
                  const SizedBox(height: 4),
                  Text(lastAtt != null
                      ? 'آخر حضور: ${DateHelper.displayDateWithDay(DateHelper.fromKey(lastAtt.dateKey))}'
                      : 'لم يسجَّل له أي حضور بعد'),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('غائب عن: ${missing.join(' - ')}'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),
            const Text('إضافة ملاحظة افتقاد',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'مثال: تواصلت معاه تليفونيًا واطمأنيت عليه...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveNote,
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('حفظ الملاحظة'),
              ),
            ),

            const SizedBox(height: 20),
            const Text('سجل الافتقاد',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (visits.isEmpty)
              const Text('لا توجد ملاحظات افتقاد بعد')
            else
              ...visits.map((v) => Card(
                    child: ListTile(
                      title: Text(v.note),
                      subtitle: Text(
                        '${DateHelper.displayDateWithDay(DateHelper.fromKey(v.dateKey))}'
                        '${v.createdBy.isNotEmpty ? "  —  ${v.createdBy}" : ""}',
                      ),
                    ),
                  )),

            const SizedBox(height: 20),
            const Text('سجل الغياب الكامل',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (absenceLog.isEmpty)
              const Text('لا يوجد غياب مسجل، الحمد لله')
            else
              ...absenceLog.map((r) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.cancel,
                        color: AppColors.absent, size: 20),
                    title: Text(r.activity),
                    trailing: Text(DateHelper.displayDate(
                        DateHelper.fromKey(r.dateKey))),
                  )),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
