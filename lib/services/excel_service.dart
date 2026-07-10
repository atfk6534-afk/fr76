import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/student_model.dart';
import '../core/utils/name_helper.dart';

/// خدمة استيراد/تصدير Excel
///
/// تنسيق الاستيراد (يتبع ما حدده المستخدم بالضبط):
///   العمود A  → رقم تسلسلي  (يُتجاهل تماماً)
///   العمود B  → الاسم الثلاثي
///   العمود C  → العنوان
///   العمود D  → العنوان التفصيلي
///   العمود E  → تاريخ الميلاد
///   العمود F  → رقم تليفون أول (واتساب)
///   العمود G  → رقم تليفون تاني
///   باقي الأعمدة تُتجاهل
class ExcelService {
  static const _uuid = Uuid();

  // ─── تصدير ───────────────────────────────────────────────────────────────

  Future<String> exportStudents(List<StudentModel> students) async {
    final excel = Excel.createExcel();
    final sheet = excel['الشباب'];
    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('الاسم الثلاثي'),
      TextCellValue('العنوان'),
      TextCellValue('العنوان التفصيلي'),
      TextCellValue('تاريخ الميلاد'),
      TextCellValue('رقم تليفون أول (واتساب)'),
      TextCellValue('رقم تليفون تاني'),
      TextCellValue('ملاحظات'),
    ]);
    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(s.fullName),
        TextCellValue(s.address),
        TextCellValue(s.addressDetail),
        TextCellValue(s.birthDate),
        TextCellValue(s.phone),
        TextCellValue(s.phone2),
        TextCellValue(s.notes),
      ]);
    }
    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/students_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  // ─── استيراد ─────────────────────────────────────────────────────────────

  Future<List<StudentModel>> importStudents(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final List<StudentModel> result = [];

    for (final tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName]!;

      for (int rowIdx = 0; rowIdx < sheet.maxRows; rowIdx++) {
        final row = sheet.row(rowIdx);

        // ─── العمود B (index 1) = الاسم الثلاثي ───
        final rawName = _cell(row, 1);

        // تخطّى أي صف لا يحتوي على اسم حقيقي
        if (rawName.isEmpty || rawName == '0') continue;

        // تخطّى الصف الأول لو كان هيدر (يبدأ بـ م أو الاسم)
        if (rowIdx == 0 &&
            (rawName == 'م' ||
             rawName == 'الاسم' ||
             rawName == 'الاسم الثلاثي' ||
             rawName == 'name')) continue;

        final address       = _cell(row, 2);  // C
        final addressDetail = _cell(row, 3);  // D
        final birthDate     = _cell(row, 4);  // E
        final phone         = _cleanPhone(_cell(row, 5)); // F
        final phone2        = _cleanPhone(_cell(row, 6)); // G

        final now = DateTime.now();
        result.add(StudentModel(
          id:            _uuid.v4(),
          fullName:      rawName,
          firstName:     NameHelper.extractFirstName(rawName),
          phone:         phone,
          phone2:        phone2 == phone ? '' : phone2,
          address:       address,
          addressDetail: addressDetail,
          birthDate:     birthDate,
          createdAt:     now,
          updatedAt:     now,
          needsSync:     true,
        ));
      }
    }
    return result;
  }

  // ─── مساعدات ─────────────────────────────────────────────────────────────

  /// استخراج قيمة خلية كنص نظيف، أو '' إن كانت فارغة
  String _cell(List<Data?> row, int col) {
    if (col >= row.length) return '';
    final val = row[col]?.value;
    if (val == null) return '';
    // بعض قيم التاريخ تكون DateCellValue أو DoubleCellValue
    if (val is DateCellValue) {
      return '${val.day.toString().padLeft(2, '0')}/'
             '${val.month.toString().padLeft(2, '0')}/'
             '${val.year}';
    }
    final str = val.toString().trim();
    return (str == 'null' || str == 'Null') ? '' : str;
  }

  /// تنظيف رقم التليفون: حذف '0' أو 'null' المنفردة
  String _cleanPhone(String raw) {
    if (raw == '0' || raw.isEmpty || raw.toLowerCase() == 'null') return '';
    return raw;
  }
}
