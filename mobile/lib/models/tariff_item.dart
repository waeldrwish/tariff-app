class TariffItem {
  final int id;
  final String hsCode;
  final String itemName;
  final String dutyRate;
  final String totalFees;
  final String description;

  const TariffItem({
    required this.id,
    required this.hsCode,
    required this.itemName,
    required this.dutyRate,
    required this.totalFees,
    required this.description,
  });

  factory TariffItem.fromJson(Map<String, dynamic> json) => TariffItem(
        id: json['id'] as int,
        hsCode: json['hs_code'] as String? ?? '',
        itemName: json['item_name'] as String? ?? '',
        dutyRate: json['duty_rate'] as String? ?? '',
        totalFees: json['total_fees'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hs_code': hsCode,
        'item_name': itemName,
        'duty_rate': dutyRate,
        'total_fees': totalFees,
        'description': description,
      };
}
