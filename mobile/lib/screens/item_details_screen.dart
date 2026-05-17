import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/tariff_item.dart';

class ItemDetailsScreen extends StatelessWidget {
  final TariffItem item;

  const ItemDetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar مخصص ───
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      colors.primary,
                      colors.tertiary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // HS Code Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.tag,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'H.S Code: ${item.hsCode.isEmpty ? "غير محدد" : item.hsCode}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.itemName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── بطاقات التفاصيل ───
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // بطاقة الرسوم
                _FeesCard(item: item)
                    .animate()
                    .fadeIn(delay: 100.ms)
                    .slideY(begin: 0.1),

                const SizedBox(height: 12),

                // تفاصيل الصنف
                if (item.description.isNotEmpty)
                  _DescriptionCard(description: item.description)
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideY(begin: 0.1),

                const SizedBox(height: 12),

                // زر نسخ HS Code
                _CopyButton(hsCode: item.hsCode)
                    .animate()
                    .fadeIn(delay: 300.ms),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── بطاقة الرسوم ───
class _FeesCard extends StatelessWidget {
  final TariffItem item;
  const _FeesCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'الرسوم الجمركية',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            _FeeRow(
              icon: Icons.percent,
              label: 'رسم الاستيراد',
              value: item.dutyRate.isEmpty ? '—' : item.dutyRate,
              highlight: true,
            ),
            if (item.serviceFee.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FeeRow(
                icon: Icons.miscellaneous_services_outlined,
                label: 'بدل الخدمات',
                value: item.serviceFee,
                highlight: false,
              ),
            ],
            const SizedBox(height: 12),
            _FeeRow(
              icon: Icons.calculate_outlined,
              label: 'رسم الاستيراد كامل',
              value: item.totalFees.isEmpty ? '—' : item.totalFees,
              highlight: false,
            ),
            if (item.unitType.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FeeRow(
                icon: Icons.straighten_outlined,
                label: 'نوع الوحدة',
                value: item.unitType,
                highlight: false,
              ),
            ],
            if (item.exportDuty.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FeeRow(
                icon: Icons.output_outlined,
                label: 'رسم التصدير',
                value: item.exportDuty,
                highlight: false,
              ),
            ],
            if (item.exportServiceFee.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FeeRow(
                icon: Icons.local_shipping_outlined,
                label: 'رسم خدمات التصدير \$ / الطن',
                value: item.exportServiceFee,
                highlight: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _FeeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? colors.primaryContainer.withOpacity(0.5)
            : colors.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: highlight ? colors.primary : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── بطاقة الوصف ───
class _DescriptionCard extends StatelessWidget {
  final String description;
  const _DescriptionCard({required this.description});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'تفاصيل الصنف',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              description,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── زر نسخ HS Code ───
class _CopyButton extends StatelessWidget {
  final String hsCode;
  const _CopyButton({required this.hsCode});

  @override
  Widget build(BuildContext context) {
    if (hsCode.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.copy),
        label: Text('نسخ رقم H.S Code: $hsCode'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: hsCode));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم نسخ رقم الصنف'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
