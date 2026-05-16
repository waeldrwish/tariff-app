import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/local_db_service.dart';
import '../services/pdf_import_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _db = LocalDbService();
  final _parser = PdfImportService();

  List<ImportedFile> _files = [];
  Map<String, int> _stats = {'total_items': 0, 'total_files': 0};
  bool _loadingFiles = false;

  // حالة الاستيراد
  bool _importing = false;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  String _progressMsg = '';
  String _lastStatus = '';
  bool _lastWasError = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loadingFiles = true);
    try {
      final results = await Future.wait([_db.listFiles(), _db.getStats()]);
      setState(() {
        _files = results[0] as List<ImportedFile>;
        _stats = results[1] as Map<String, int>;
      });
    } catch (_) {}
    setState(() => _loadingFiles = false);
  }

  // ─── اختيار PDF واستيراده ──────────────────────────────────────────
  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    final filename = result.files.single.name;

    setState(() {
      _importing = true;
      _progressCurrent = 0;
      _progressTotal = 0;
      _progressMsg = 'جاري فتح الملف...';
      _lastStatus = '';
    });

    try {
      // قراءة وتحليل PDF على الجهاز
      final items = await _parser.parse(
        filePath,
        onProgress: (cur, tot, msg) {
          setState(() {
            _progressCurrent = cur;
            _progressTotal = tot;
            _progressMsg = msg;
          });
        },
      );

      if (items.isEmpty) {
        _setStatus(
          'لم يُعثر على جداول قابلة للقراءة.\n'
          'تأكد أن PDF يحتوي على نصوص وليس صوراً ممسوحة ضوئياً.',
          isError: true,
        );
        return;
      }

      setState(() => _progressMsg = 'جاري الحفظ في قاعدة البيانات...');

      // حفظ في SQLite المحلي
      final count =
          await _db.insertItems(items.cast<Map<String, String>>(), filename);

      _setStatus('تم استيراد $count صنف من "$filename" بنجاح ✓');
      await _refresh();
    } catch (e) {
      _setStatus('خطأ أثناء المعالجة:\n$e', isError: true);
    } finally {
      setState(() => _importing = false);
    }
  }

  void _setStatus(String msg, {bool isError = false}) {
    setState(() {
      _lastStatus = msg;
      _lastWasError = isError;
    });
  }

  Future<void> _confirmDelete(ImportedFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل تريد حذف "${file.filename}" و${file.itemCount} صنف مرتبط به؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteFile(file.id, file.filename);
    _setStatus('تم حذف "${file.filename}"');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد التعرفة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── إحصائيات ───
            _StatsRow(stats: _stats).animate().fadeIn(),

            const SizedBox(height: 16),

            // ─── لافتة "بدون إنترنت" ───
            _OfflineBadge().animate().fadeIn(delay: 80.ms),

            const SizedBox(height: 16),

            // ─── بطاقة الاستيراد ───
            _ImportCard(
              importing: _importing,
              current: _progressCurrent,
              total: _progressTotal,
              msg: _progressMsg,
              lastStatus: _lastStatus,
              isError: _lastWasError,
              onImport: _pickAndImport,
            ).animate().fadeIn(delay: 120.ms),

            const SizedBox(height: 20),

            // ─── قائمة الملفات ───
            Text(
              'الملفات المستوردة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),

            if (_loadingFiles)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_files.isEmpty)
              _EmptyFiles()
            else
              ..._files.asMap().entries.map(
                    (e) => _FileCard(
                      file: e.value,
                      onDelete: () => _confirmDelete(e.value),
                    )
                        .animate(delay: Duration(milliseconds: 50 * e.key))
                        .fadeIn()
                        .slideX(begin: 0.05),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─── شارة "بدون إنترنت" ───────────────────────────────────────────────
class _OfflineBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'يعمل بدون إنترنت — البيانات محفوظة على هاتفك مباشرة',
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── إحصائيات ─────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            icon: Icons.inventory_2_outlined,
            label: 'إجمالي الأصناف',
            value: '${stats['total_items'] ?? 0}',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            icon: Icons.picture_as_pdf,
            label: 'ملفات مستوردة',
            value: '${stats['total_files'] ?? 0}',
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _Stat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── بطاقة الاستيراد ──────────────────────────────────────────────────
class _ImportCard extends StatelessWidget {
  final bool importing;
  final int current, total;
  final String msg, lastStatus;
  final bool isError;
  final VoidCallback onImport;

  const _ImportCard({
    required this.importing,
    required this.current,
    required this.total,
    required this.msg,
    required this.lastStatus,
    required this.isError,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = total > 0 ? current / total : null;

    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // أيقونة
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: importing
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        color: cs.primary,
                      ),
                    )
                  : Icon(Icons.picture_as_pdf,
                      size: 40, color: cs.primary),
            ),
            const SizedBox(height: 12),

            Text(
              importing ? 'جاري معالجة الملف...' : 'استيراد ملف التعرفة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),

            // رسالة الحالة
            if (importing)
              Column(children: [
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  msg,
                  style: TextStyle(fontSize: 12, color: cs.primary),
                  textAlign: TextAlign.center,
                ),
              ])
            else ...[
              Text(
                'يُقرأ الملف كاملاً على هاتفك — لا يُرسل لأي سيرفر',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('اختر ملف PDF من هاتفك'),
                  onPressed: onImport,
                ),
              ),
              if (lastStatus.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isError
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isError
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    lastStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isError
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── لا توجد ملفات ────────────────────────────────────────────────────
class _EmptyFiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.folder_open,
                size: 56,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              'لا توجد ملفات مستوردة بعد',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── بطاقة ملف مستورد ─────────────────────────────────────────────────
class _FileCard extends StatelessWidget {
  final ImportedFile file;
  final VoidCallback onDelete;

  const _FileCard({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
        ),
        title: Text(
          file.filename,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${file.itemCount} صنف  |  ${file.importedAt.split("T").first}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
