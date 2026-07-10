import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../widgets/student_card.dart';
import 'add_edit_student_screen.dart';
import 'student_details_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, String studentId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف $name؟'),
        content: const Text('هيتحذف من كل الأجهزة. متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<StudentProvider>().deleteStudent(studentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<StudentProvider>();
    final settings  = context.watch<SettingsProvider>();
    final students  = provider.filteredStudents;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'بحث بالاسم أو الهاتف...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: provider.search,
              )
            : const Text('الشباب'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchCtrl.clear();
                provider.search('');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'إضافة شاب',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Text('${students.length} شاب',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? Center(
                    child: Text(
                      _searchCtrl.text.isNotEmpty
                          ? 'لا توجد نتائج للبحث'
                          : 'لا يوجد شباب بعد',
                    ),
                  )
                : ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return StudentCard(
                        student: student,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StudentDetailsScreen(studentId: student.id),
                          ),
                        ),
                        onWhatsapp: () async {
                          final message = WhatsappHelper.buildMessage(
                              settings.whatsappMessage, student.firstName);
                          final opened = await WhatsappHelper.openWhatsapp(
                              phone: student.phone, message: message);
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تعذر فتح واتساب، تأكد من رقم الهاتف')),
                            );
                          }
                        },
                        onEdit: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddEditStudentScreen(student: student),
                          ),
                        ),
                        onDelete: () =>
                            _confirmDelete(context, student.id, student.fullName),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
