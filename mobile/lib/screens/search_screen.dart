import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../models/tariff_item.dart';
import '../services/local_db_service.dart';
import 'item_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _db = LocalDbService();

  List<TariffItem> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String _errorMsg = '';

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _errorMsg = '';
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMsg = '';
      _hasSearched = true;
    });
    try {
      // البحث في SQLite المحلي — لا يحتاج إنترنت
      final items = await _db.search(query.trim());
      if (mounted) setState(() => _results = items);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'خطأ في قاعدة البيانات:\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
      _errorMsg = '';
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceVariant.withOpacity(0.3),
      body: CustomScrollView(
        slivers: [
          // ─── AppBar مع شريط البحث ───
          SliverAppBar(
            floating: true,
            snap: true,
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primary, colors.primaryContainer],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.account_balance,
                              color: Colors.white, size: 26),
                          const SizedBox(width: 10),
                          Text(
                            'التعرفة الجمركية',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.storage,
                              color: Colors.white54, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'بحث محلي — يعمل بدون إنترنت',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _SearchBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onTextChanged,
                  onClear: _clearSearch,
                  onSubmit: (_) => _search(_controller.text),
                ),
              ),
            ),
          ),

          // ─── المحتوى ───
          if (_loading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ShimmerTile(),
                childCount: 6,
              ),
            )
          else if (_errorMsg.isNotEmpty)
            SliverFillRemaining(
                child: _ErrorState(message: _errorMsg))
          else if (!_hasSearched)
            SliverFillRemaining(child: _EmptyState())
          else if (_results.isEmpty)
            SliverFillRemaining(
                child: _NoResults(query: _controller.text))
          else
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) =>
                      _ResultCard(item: _results[i], index: i),
                  childCount: _results.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── مربع البحث ───────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged, onSubmit;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmit,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث بالاسم أو رقم H.S Code...',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: const Icon(Icons.search, size: 22),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, val, __) => (val as TextEditingValue).text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClear,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

// ─── بطاقة نتيجة ─────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final TariffItem item;
  final int index;
  const _ResultCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ItemDetailsScreen(item: item)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.hsCode.isEmpty ? '—' : item.hsCode,
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.dutyRate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'رسم: ${item.dutyRate}',
                      style: TextStyle(
                          fontSize: 12, color: cs.secondary),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: cs.outline),
          ]),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 35))
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.08, end: 0);
  }
}

// ─── حالات UI ─────────────────────────────────────────────────────────
class _ShimmerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'ابدأ بكتابة اسم الصنف\nأو رقم H.S Code',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).scale(
            begin: const Offset(0.9, 0.9),
          ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text('لا توجد نتائج لـ "$query"',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            'جرّب كلمة مختلفة أو تأكد من استيراد ملف PDF',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
