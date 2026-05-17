class TariffItem {
  final int id;
  final String hsCode;
  final String itemName;
  final String dutyRate;       // رسم الاستيراد
  final String serviceFee;     // بدل خدمات
  final String totalFees;      // رسم الاستيراد كامل
  final String unitType;       // نوع الوحدة
  final String exportDuty;     // رسم التصدير
  final String exportServiceFee; // رسم خدمات تصدير $ للطن
  final String description;

  const TariffItem({
    required this.id,
    required this.hsCode,
    required this.itemName,
    required this.dutyRate,
    required this.serviceFee,
    required this.totalFees,
    required this.unitType,
    required this.exportDuty,
    required this.exportServiceFee,
    required this.description,
  });

  factory TariffItem.fromJson(Map<String, dynamic> json) => TariffItem(
        id: json['id'] as int,
        hsCode: json['hs_code'] as String? ?? '',
        itemName: json['item_name'] as String? ?? '',
        dutyRate: json['duty_rate'] as String? ?? '',
        serviceFee: json['service_fee'] as String? ?? '',
        totalFees: json['total_fees'] as String? ?? '',
        unitType: json['unit_type'] as String? ?? '',
        exportDuty: json['export_duty'] as String? ?? '',
        exportServiceFee: json['export_service_fee'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hs_code': hsCode,
        'item_name': itemName,
        'duty_rate': dutyRate,
        'service_fee': serviceFee,
        'total_fees': totalFees,
        'unit_type': unitType,
        'export_duty': exportDuty,
        'export_service_fee': exportServiceFee,
        'description': description,
      };
}
