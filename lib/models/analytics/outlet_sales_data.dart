import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель агрегированных данных продаж по торговой точке
class OutletSalesData {
  final String outletId;
  final String outletName;
  final String outletAddress;
  final double totalSales;
  final int invoiceCount;
  final List<ProductSalesData> products;
  final List<InvoiceSummary> invoices;
  final DateTime periodStart;
  final DateTime periodEnd;

  const OutletSalesData({
    required this.outletId,
    required this.outletName,
    required this.outletAddress,
    required this.totalSales,
    required this.invoiceCount,
    required this.products,
    required this.invoices,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Создание из Firestore данных
  factory OutletSalesData.fromMap(Map<String, dynamic> map) {
    return OutletSalesData(
      outletId: map['outletId'] ?? '',
      outletName: map['outletName'] ?? '',
      outletAddress: map['outletAddress'] ?? '',
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: map['invoiceCount'] ?? 0,
      products: (map['products'] as List<dynamic>?)
          ?.map((e) => ProductSalesData.fromMap(e as Map<String, dynamic>))
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
      'outletId': outletId,
      'outletName': outletName,
      'outletAddress': outletAddress,
      'totalSales': totalSales,
      'invoiceCount': invoiceCount,
      'products': products.map((e) => e.toMap()).toList(),
      'invoices': invoices.map((e) => e.toMap()).toList(),
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
    };
  }

  /// Создание копии с изменениями
  OutletSalesData copyWith({
    String? outletId,
    String? outletName,
    String? outletAddress,
    double? totalSales,
    int? invoiceCount,
    List<ProductSalesData>? products,
    List<InvoiceSummary>? invoices,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    return OutletSalesData(
      outletId: outletId ?? this.outletId,
      outletName: outletName ?? this.outletName,
      outletAddress: outletAddress ?? this.outletAddress,
      totalSales: totalSales ?? this.totalSales,
      invoiceCount: invoiceCount ?? this.invoiceCount,
      products: products ?? this.products,
      invoices: invoices ?? this.invoices,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OutletSalesData &&
        other.outletId == outletId &&
        other.outletName == outletName &&
        other.outletAddress == outletAddress &&
        other.totalSales == totalSales &&
        other.invoiceCount == invoiceCount;
  }

  @override
  int get hashCode {
    return outletId.hashCode ^
        outletName.hashCode ^
        outletAddress.hashCode ^
        totalSales.hashCode ^
        invoiceCount.hashCode;
  }

  @override
  String toString() {
    return 'OutletSalesData(outletId: $outletId, outletName: $outletName, totalSales: $totalSales, invoiceCount: $invoiceCount)';
  }
}

/// Модель данных продаж товара в торговой точке
class ProductSalesData {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double totalAmount;
  final bool isBonus;

  const ProductSalesData({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.totalAmount,
    required this.isBonus,
  });

  factory ProductSalesData.fromMap(Map<String, dynamic> map) {
    return ProductSalesData(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: map['quantity'] ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      isBonus: map['isBonus'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'totalAmount': totalAmount,
      'isBonus': isBonus,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductSalesData &&
        other.productId == productId &&
        other.productName == productName &&
        other.price == price &&
        other.quantity == quantity &&
        other.totalAmount == totalAmount &&
        other.isBonus == isBonus;
  }

  @override
  int get hashCode {
    return productId.hashCode ^
        productName.hashCode ^
        price.hashCode ^
        quantity.hashCode ^
        totalAmount.hashCode ^
        isBonus.hashCode;
  }

  @override
  String toString() {
    return 'ProductSalesData(productId: $productId, productName: $productName, quantity: $quantity, totalAmount: $totalAmount, isBonus: $isBonus)';
  }
}

/// Краткая сводка по накладной
class InvoiceSummary {
  final String invoiceId;
  final DateTime date;
  final String salesRepName;
  final double totalAmount;
  final int status;

  const InvoiceSummary({
    required this.invoiceId,
    required this.date,
    required this.salesRepName,
    required this.totalAmount,
    required this.status,
  });

  factory InvoiceSummary.fromMap(Map<String, dynamic> map) {
    return InvoiceSummary(
      invoiceId: map['invoiceId'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      salesRepName: map['salesRepName'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceId': invoiceId,
      'date': Timestamp.fromDate(date),
      'salesRepName': salesRepName,
      'totalAmount': totalAmount,
      'status': status,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvoiceSummary &&
        other.invoiceId == invoiceId &&
        other.date == date &&
        other.salesRepName == salesRepName &&
        other.totalAmount == totalAmount &&
        other.status == status;
  }

  @override
  int get hashCode {
    return invoiceId.hashCode ^
        date.hashCode ^
        salesRepName.hashCode ^
        totalAmount.hashCode ^
        status.hashCode;
  }

  @override
  String toString() {
    return 'InvoiceSummary(invoiceId: $invoiceId, date: $date, salesRepName: $salesRepName, totalAmount: $totalAmount)';
  }
} 