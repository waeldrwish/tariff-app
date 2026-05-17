import 'dart:io';
import 'package:excel/excel.dart';

/// يقرأ ملف Excel (.xlsx/.xls) ويستخرج أصناف التعرفة منه.
/// يُستدعى دائماً من داخل Isolate منفصل عبر _fileWorkerEntry في admin_screen.dart
class ExcelImportService {
  static final _hsRegex = RegExp(r'^\d{2,12}([.\-]\d+)*$');

  Future<List<Map<String, String>>> parse(
    String filePath, {
    void Function(int current, int total, String msg)? onProgress,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final workbook = Excel.decodeBytes(bytes);

    final items = <Map<String, String>>[];
    final seenCodes = <String>{};

    final sheetNames = workbook.tables.keys.toList();
    final totalSheets = sheetNames.length;

    for (int s = 0; s < totalSheets; s++) {
      final sheet = workbook.tables[sheetNames[s]]!;
      final rows = sheet.rows;
      final totalRows = rows.length;

      for (int r = 0; r < totalRows; r++) {
        if (r % 100 == 0) {
          onProgress?.call(
            s * totalRows + r,
            totalSheets * totalRows,
            'معالجة الورقة ${s + 1} من $totalSheets، صف $r من $totalRows...',
          );
        }

        // نحتفظ بكل الخلايا بما فيها الفارغة للحفاظ على المواضع الصحيحة للأعمدة
        final parts = rows[r]
            .map((cell) => _cellText(cell))
            .toList();

        _tryExtract(parts, items, seenCodes);
      }
    }

    return items;
  }

  String _cellText(Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  void _tryExtract(
    List<String> parts,
    List<Map<String, String>> out,
    Set<String> seen,
  ) {
    // نبحث عن HS code أولاً - إذا لم يوجد فالصف ليس بيانات
    int hsIdx = -1;
    for (int i = 0; i < parts.length; i++) {
      if (_looksLikeHs(parts[i])) {
        hsIdx = i;
        break;
      }
    }
    if (hsIdx < 0) return;

    final hsCode = parts[hsIdx];
    if (seen.contains(hsCode)) return;
    seen.add(hsCode);

    out.add({
      'hs_code': hsCode,
      'item_name': _get(parts, hsIdx + 1),
      'duty_rate': _get(parts, hsIdx + 2),        // رسم الاستيراد
      'service_fee': _get(parts, hsIdx + 3),      // بدل خدمات
      'total_fees': _get(parts, hsIdx + 4),       // رسم الاستيراد كامل
      'unit_type': _get(parts, hsIdx + 5),        // نوع الوحدة
      'export_duty': _get(parts, hsIdx + 6),      // رسم التصدير
      'export_service_fee': _get(parts, hsIdx + 7), // رسم خدمات تصدير
    });
  }

  bool _looksLikeHs(String s) {
    final clean = s.replaceAll(RegExp(r'[\s ]'), '');
    return _hsRegex.hasMatch(clean) && clean.length >= 2;
  }

  String _get(List<String> list, int i) =>
      i < list.length ? list[i] : '';
}
