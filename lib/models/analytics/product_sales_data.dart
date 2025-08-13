import 'package:cloud_firestore/cloud_firestore.dart';
import 'outlet_sales_data.dart';

/// Модель агрегированных данных продаж по товару
class ProductAnalyticsData {
  final String productId;
  final String productName;
  final double price;
  final double totalSales;
  final int totalQuantity;
  final int bonusQuantity;
  final double bonusAmount;
  final int regularQuantity;
  final double regularAmount;
  final List<OutletSalesInfo> outletSales;
  final List<InvoiceSummary> invoices;
  final DateTime periodStart;
  final DateTime periodEnd;

  const ProductAnalyticsData({
    required this.productId,
    required this.productName,
    required this.price,
    required this.totalSales,
    required this.totalQuantity,
    required this.bonusQuantity,
    required this.bonusAmount,
    required this.regularQuantity,
    required this.regularAmount,
    required this.outletSales,
    required this.invoices,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Создание из Firestore данных
  factory ProductAnalyticsData.fromMap(Map<String, dynamic> map) {
    return ProductAnalyticsData(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalQuantity: map['totalQuantity'] ?? 0,
      bonusQuantity: map['bonusQuantity'] ?? 0,
      bonusAmount: (map['bonusAmount'] as num?)?.toDouble() ?? 0.0,
      regularQuantity: map['regularQuantity'] ?? 0,
      regularAmount: (map['regularAmount'] as num?)?.toDouble() ?? 0.0,
      outletSales: (map['outletSales'] as List<dynamic>?)
          ?.map((e) => OutletSalesInfo.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      invoices: (map['invoices'] as List<dynamic>?)
          ?.map((e) => InvoiceSummary.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      periodStart: (map['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (map['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'totalSales': totalSales,
      'totalQuantity': totalQuantity,
      'bonusQuantity': bonusQuantity,
      'bonusAmount': bonusAmount,
      'regularQuantity': regularQuantity,
      'regularAmount': regularAmount,
      'outletSales': outletSales.map((e) => e.toMap()).toList(),
      'invoices': invoices.map((e) => e.toMap()).toList(),
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
    };
  }

  /// Создание копии с изменениями
  ProductAnalyticsData copyWith({
    String? productId,
    String? productName,
    double? price,
    double? totalSales,
    int? totalQuantity,
    int? bonusQuantity,
    double? bonusAmount,
    int? regularQuantity,
    double? regularAmount,
    List<OutletSalesInfo>? outletSales,
    List<InvoiceSummary>? invoices,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    return ProductAnalyticsData(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      totalSales: totalSales ?? this.totalSales,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      bonusQuantity: bonusQuantity ?? this.bonusQuantity,
      bonusAmount: bonusAmount ?? this.bonusAmount,
      regularQuantity: regularQuantity ?? this.regularQuantity,
      regularAmount: regularAmount ?? this.regularAmount,
      outletSales: outletSales ?? this.outletSales,
      invoices: invoices ?? this.invoices,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductAnalyticsData &&
        other.productId == productId &&
        other.productName == productName &&
        other.price == price &&
        other.totalSales == totalSales &&
        other.totalQuantity == totalQuantity;
  }

  @override
  int get hashCode {
    return productId.hashCode ^
        productName.hashCode ^
        price.hashCode ^
        totalSales.hashCode ^
        totalQuantity.hashCode;
  }

  @override
  String toString() {
    return 'ProductAnalyticsData(productId: $productId, productName: $productName, totalSales: $totalSales, totalQuantity: $totalQuantity)';
  }
}

/// Модель продаж товара по торговой точке
class OutletSalesInfo {
  final String outletId;
  final String outletName;
  final String outletAddress;
  final int regularQuantity;
  final double regularAmount;
  final int bonusQuantity;
  final double bonusAmount;
  final double totalAmount;

  const OutletSalesInfo({
    required this.outletId,
    required this.outletName,
    required this.outletAddress,
    required this.regularQuantity,
    required this.regularAmount,
    required this.bonusQuantity,
    required this.bonusAmount,
    required this.totalAmount,
  });

  factory OutletSalesInfo.fromMap(Map<String, dynamic> map) {
    return OutletSalesInfo(
      outletId: map['outletId'] ?? '',
      outletName: map['outletName'] ?? '',
      outletAddress: map['outletAddress'] ?? '',
      regularQuantity: map['regularQuantity'] ?? 0,
      regularAmount: (map['regularAmount'] as num?)?.toDouble() ?? 0.0,
      bonusQuantity: map['bonusQuantity'] ?? 0,
      bonusAmount: (map['bonusAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'outletId': outletId,
      'outletName': outletName,
      'outletAddress': outletAddress,
      'regularQuantity': regularQuantity,
      'regularAmount': regularAmount,
      'bonusQuantity': bonusQuantity,
      'bonusAmount': bonusAmount,
      'totalAmount': totalAmount,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OutletSalesInfo &&
        other.outletId == outletId &&
        other.outletName == outletName &&
        other.outletAddress == outletAddress &&
        other.regularQuantity == regularQuantity &&
        other.regularAmount == regularAmount &&
        other.bonusQuantity == bonusQuantity &&
        other.bonusAmount == bonusAmount &&
        other.totalAmount == totalAmount;
  }

  @override
  int get hashCode {
    return outletId.hashCode ^
        outletName.hashCode ^
        outletAddress.hashCode ^
        regularQuantity.hashCode ^
        regularAmount.hashCode ^
        bonusQuantity.hashCode ^
        bonusAmount.hashCode ^
        totalAmount.hashCode;
  }

  @override
  String toString() {
    return 'OutletSalesInfo(outletId: $outletId, outletName: $outletName, totalAmount: $totalAmount)';
  }
}


