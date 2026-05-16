import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// يقرأ ملف PDF على الجهاز ويستخرج أصناف التعرفة منه.
/// يُستدعى دائماً من داخل Isolate منفصل عبر _pdfWorkerEntry في admin_screen.dart
/// حتى لا يتجمد Main Thread.
class PdfImportService {
  // نمط رقم HS Code: يبدأ بأرقام وقد يحتوي نقاط
  static final _hsRegex = RegExp(r'^\d{2,12}([.\-]\d+)*$');

  // كلمات رأس الجدول يجب تجاهلها
  static const _headerWords = {
    'hs', 'code', 'رقم', 'بند', 'item', 'اسم', 'duty', 'rate',
    'fees', 'الصنف', 'الرسم', 'رسوم', 'إجمالي', 'وصف', 'description',
    'رسم', 'نسبة', 'البيان', 'total', 'الرسوم',
  };

  Future<List<Map<String, String>>> parse(
    String filePath, {
    void Function(int current, int total, String msg)? onProgress,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);

    final items = <Map<String, String>>[];
    final seenCodes = <String>{};
    final total = doc.pages.count;

    for (int i = 0; i < total; i++) {
      onProgress?.call(i + 1, total, 'معالجة صفحة ${i + 1} من $total...');

      final extractor = PdfTextExtractor(doc);

      try {
        // المحاولة الأولى: استخراج بالمواضع (أدق للجداول)
        final lines = extractor.extractTextLines(
          startPageIndex: i,
          endPageIndex: i,
        );
        _parsePositioned(lines, items, seenCodes);
      } catch (_) {
        // خطة الطوارئ: استخراج نصي بسيط
        final text =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        _parseText(text, items, seenCodes);
      }
    }

    doc.dispose();
    return items;
  }

  // ─── استخراج بالمواضع (X,Y) ──────────────────────────────────────────
  void _parsePositioned(
    List<TextLine> lines,
    List<Map<String, String>> out,
    Set<String> seen,
  ) {
    if (lines.isEmpty) return;

    // تجميع الأسطر في صفوف بناءً على موضع Y (شبكة 6px)
    final rowMap = <int, List<TextLine>>{};
    for (final line in lines) {
      final y = (line.bounds.top / 6).round();
      rowMap.putIfAbsent(y, () => []).add(line);
    }

    // ترتيب الصفوف عمودياً، والخلايا أفقياً
    final rows = rowMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in rows) {
      final cells = entry.value
        ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

      final texts = cells
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      _tryExtract(texts, out, seen);
    }
  }

  // ─── استخراج نصي بسيط (Fallback) ─────────────────────────────────────
  void _parseText(
    String text,
    List<Map<String, String>> out,
    Set<String> seen,
  ) {
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      // تقسيم بمسافات متعددة أو tab
      final parts = line
          .split(RegExp(r'\t|\s{2,}'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      _tryExtract(parts, out, seen);
    }
  }

  // ─── منطق الاستخراج المشترك ──────────────────────────────────────────
  void _tryExtract(
    List<String> parts,
    List<Map<String, String>> out,
    Set<String> seen,
  ) {
    if (parts.length < 2) return;

    // تجاهل صفوف الرأس
    if (_isHeader(parts.first)) return;

    // البحث عن رقم HS Code بين الخلايا
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
      'duty_rate': _get(parts, hsIdx + 2),
      'total_fees': _get(parts, hsIdx + 3),
      'description': _get(parts, hsIdx + 4),
    });
  }

  bool _looksLikeHs(String s) {
    final clean = s.replaceAll(RegExp(r'[\s ]'), '');
    return _hsRegex.hasMatch(clean) && clean.length >= 2;
  }

  bool _isHeader(String s) {
    final lower = s.toLowerCase();
    return _headerWords.any((w) => lower.contains(w));
  }

  String _get(List<String> list, int i) =>
      i < list.length ? list[i] : '';
}
