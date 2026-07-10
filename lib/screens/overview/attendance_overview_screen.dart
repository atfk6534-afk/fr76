import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../models/attendance_model.dart';

class AttendanceOverviewScreen extends StatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  State<AttendanceOverviewScreen> createState() => _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<AttendanceOverviewScreen> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendPro  = context.watch<AttendanceProvider>();
    final students   = context.watch<StudentProvider>().allStudents;
    final allRecords = attendPro.getAll();

    final nameMap = <String, String>{
      for (final s in students) s.id: s.fullName,
    };

    final Map<String, List<AttendanceRecord>> byDate = {};
    for (final r in allRecords) {
      byDate.putIfAbsent(r.dateKey, () => []).add(r);
    }
    final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    // فلترة البحث حسب التاريخ أو الاسم
    final filtered = _query.trim().isEmpty
        ? sortedDates
        : sortedDates.where((key) {
            final date = DateHelper.fromKey(key);
            final dateStr = DateHelper.displayDateWithDay(date);
            if (dateStr.contains(_query)) return true;
            // بحث في أسماء الشباب
            final records = byDate[key]!;
            return records.any((r) =>
                (nameMap[r.studentId] ?? '').contains(_query));
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الأيام'),
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
                hintText: 'بحث بالتاريخ أو اسم الشاب...',
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
      body: filtered.isEmpty
          ? Center(
              child: Text(
                  _query.isEmpty ? 'لم يتم تسجيل أي حضور بعد' : 'لا توجد نتائج'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final dateKey = filtered[index];
                final records = byDate[dateKey]!;
                final present = records.where((r) => r.isPresent).length;
                final absent  = records.where((r) => !r.isPresent).length;
                final total   = present + absent;
                final pct     = total == 0 ? 0.0 : (present / total) * 100;

                final Map<String, List<AttendanceRecord>> byActivity = {};
                for (final r in records) {
                  byActivity.putIfAbsent(r.activity, () => []).add(r);
                }

                final date    = DateHelper.fromKey(dateKey);
                final dateStr = DateHelper.displayDateWithDay(date);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _pctColor(pct).withValues(alpha: 0.15),
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _pctColor(pct)),
                      ),
                    ),
                    title: Text(dateStr,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'حضر $present من $total • ${byActivity.keys.length} نشاط',
                        style: const TextStyle(fontSize: 12)),
                    children: byActivity.entries.map((entry) {
                      final activity   = entry.key;
                      final actRecords = entry.value;
                      final actPresent = actRecords.where((r) => r.isPresent).length;
                      final actTotal   = actRecords.length;
                      final presentNames = actRecords
                          .where((r) => r.isPresent)
                          .map((r) => nameMap[r.studentId] ?? r.studentId)
                          .toList();
                      final absentNames  = actRecords
                          .where((r) => !r.isPresent)
                          .map((r) => nameMap[r.studentId] ?? r.studentId)
                          .toList();

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_note,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(activity,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text('$actPresent / $actTotal',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _pctColor(actTotal == 0
                                              ? 0
                                              : actPresent / actTotal * 100))),
                                ],
                              ),
                            ),
                            if (presentNames.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 14, color: AppColors.present),
                                  const SizedBox(width: 4),
                                  Expanded(
                                      child: Text('حضر: ${presentNames.join('، ')}',
                                          style: const TextStyle(fontSize: 12))),
                                ],
                              ),
                            ],
                            if (absentNames.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.cancel,
                                      size: 14, color: AppColors.absent),
                                  const SizedBox(width: 4),
                                  Expanded(
                                      child: Text('غاب: ${absentNames.join('، ')}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.absent))),
                                ],
                              ),
                            ],
                            const Divider(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }

  Color _pctColor(double pct) {
    if (pct >= 75) return AppColors.present;
    if (pct >= 50) return AppColors.warning;
    return AppColors.absent;
  }
}
