import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analytics/outlet_sales_data.dart';
import '../services/analytics_service.dart';
import '../services/excel_export_service.dart';

/// Экран аналитики продаж по торговым точкам
class OutletSalesAnalyticsScreen extends StatefulWidget {
  const OutletSalesAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<OutletSalesAnalyticsScreen> createState() => _OutletSalesAnalyticsScreenState();
}

class _OutletSalesAnalyticsScreenState extends State<OutletSalesAnalyticsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<OutletSalesData> _outletSalesData = [];
  bool _isLoading = false;
  bool _isExporting = false;
  final Set<String> _expandedOutlets = <String>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Загрузка данных аналитики
  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await AnalyticsService.getOutletSalesAnalytics(
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _outletSalesData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки данных: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Экспорт данных в Excel
  Future<void> _exportToExcel() async {
    if (_isExporting || _outletSalesData.isEmpty) return;

    setState(() {
      _isExporting = true;
    });

    try {
      await ExcelExportService.exportOutletAnalyticsToExcel(
        outletSalesData: _outletSalesData,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Отчет экспортирован успешно'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  /// Выбор даты начала периода
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _loadData();
    }
  }

  /// Выбор даты окончания периода
  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      _loadData();
    }
  }

  /// Сброс фильтров
  void _resetFilters() {
    setState(() {
      _startDate = DateTime.now().subtract(const Duration(days: 30));
      _endDate = DateTime.now();
    });
    _loadData();
  }

  /// Переключение разворачивания карточки
  void _toggleExpanded(String outletId) {
    setState(() {
      if (_expandedOutlets.contains(outletId)) {
        _expandedOutlets.remove(outletId);
      } else {
        _expandedOutlets.add(outletId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Продажи по торговым точкам'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            onPressed: _isExporting ? null : _exportToExcel,
            tooltip: 'Экспорт в Excel',
          ),
        ],
      ),
      body: Column(
        children: [
          // Панель фильтров
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Период с:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectStartDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd.MM.yyyy').format(_startDate),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Период по:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectEndDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd.MM.yyyy').format(_endDate),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Сбросить фильтры'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.search),
                        label: const Text('Применить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Содержимое
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _outletSalesData.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет данных для отображения',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _outletSalesData.length,
                        itemBuilder: (context, index) {
                          final outletData = _outletSalesData[index];
                          final isExpanded = _expandedOutlets.contains(outletData.outletId);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              children: [
                                // Заголовок карточки
                                ListTile(
                                  title: Text(
                                    outletData.outletName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(outletData.outletAddress),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.attach_money,
                                            size: 16,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${outletData.totalSales.toStringAsFixed(2)} ₸',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.receipt,
                                            size: 16,
                                            color: Colors.blue[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${outletData.invoiceCount} накладных',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                    ),
                                    onPressed: () => _toggleExpanded(outletData.outletId),
                                  ),
                                ),
                                
                                // Развернутое содержимое
                                if (isExpanded) ...[
                                  const Divider(height: 1),
                                  
                                  // Детализация по товарам
                                  if (outletData.products.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Товары:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...outletData.products.map((product) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    product.productName,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    '${product.quantity} шт.',
                                                    style: const TextStyle(fontSize: 12),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    '${product.totalAmount.toStringAsFixed(2)} ₸',
                                                    style: const TextStyle(fontSize: 12),
                                                    textAlign: TextAlign.end,
                                                  ),
                                                ),
                                                if (product.isBonus)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange[100],
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'БОНУС',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.orange,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          )).toList(),
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                  // Список накладных
                                  if (outletData.invoices.isNotEmpty) ...[
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Накладные:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...outletData.invoices.map((invoice) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    DateFormat('dd.MM.yyyy').format(invoice.date),
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    invoice.salesRepName,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    '${invoice.totalAmount.toStringAsFixed(2)} ₸',
                                                    style: const TextStyle(fontSize: 12),
                                                    textAlign: TextAlign.end,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )).toList(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

