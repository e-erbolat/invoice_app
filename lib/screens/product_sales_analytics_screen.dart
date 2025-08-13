import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analytics/product_sales_data.dart';
import '../services/analytics_service.dart';
import '../services/excel_export_service.dart';

/// Экран аналитики продаж по товарам
class ProductSalesAnalyticsScreen extends StatefulWidget {
  const ProductSalesAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<ProductSalesAnalyticsScreen> createState() => _ProductSalesAnalyticsScreenState();
}

class _ProductSalesAnalyticsScreenState extends State<ProductSalesAnalyticsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _searchQuery = '';
  List<ProductAnalyticsData> _productAnalyticsData = [];
  bool _isLoading = false;
  bool _isExporting = false;
  final Set<String> _expandedProducts = <String>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Загрузка данных аналитики
  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await AnalyticsService.getProductSalesAnalytics(
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      setState(() {
        _productAnalyticsData = data;
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
    if (_isExporting || _productAnalyticsData.isEmpty) return;

    setState(() {
      _isExporting = true;
    });

    try {
      await ExcelExportService.exportProductAnalyticsToExcel(
        productAnalyticsData: _productAnalyticsData,
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
      _searchQuery = '';
      _searchController.clear();
    });
    _loadData();
  }

  /// Поиск по товарам
  void _performSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
    _loadData();
  }

  /// Переключение разворачивания карточки
  void _toggleExpanded(String productId) {
    setState(() {
      if (_expandedProducts.contains(productId)) {
        _expandedProducts.remove(productId);
      } else {
        _expandedProducts.add(productId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Продажи по товарам'),
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
                // Поиск
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию товара...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
                const SizedBox(height: 16),
                
                // Выбор периода
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
                : _productAnalyticsData.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет данных для отображения',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _productAnalyticsData.length,
                        itemBuilder: (context, index) {
                          final productData = _productAnalyticsData[index];
                          final isExpanded = _expandedProducts.contains(productData.productId);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              children: [
                                // Заголовок карточки
                                ListTile(
                                  title: Text(
                                    productData.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.attach_money,
                                            size: 16,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${productData.totalSales.toStringAsFixed(2)} ₸',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.inventory,
                                            size: 16,
                                            color: Colors.blue[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${productData.totalQuantity} шт.',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          // Обычные продажи
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Обычные: ${productData.regularQuantity} шт. (${productData.regularAmount.toStringAsFixed(2)} ₸)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Бонусные продажи
                                          if (productData.bonusQuantity > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[100],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Бонусы: ${productData.bonusQuantity} шт. (${productData.bonusAmount.toStringAsFixed(2)} ₸)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.orange[700],
                                                  fontWeight: FontWeight.bold,
                                                ),
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
                                    onPressed: () => _toggleExpanded(productData.productId),
                                  ),
                                ),
                                
                                // Развернутое содержимое
                                if (isExpanded) ...[
                                  const Divider(height: 1),
                                  
                                  // Продажи по торговым точкам
                                  if (productData.outletSales.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Продажи по торговым точкам:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...productData.outletSales.map((outlet) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  outlet.outletName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  outlet.outletAddress,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    // Обычные продажи
                                                    Expanded(
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blue[50],
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '${outlet.regularQuantity} шт. (${outlet.regularAmount.toStringAsFixed(2)} ₸)',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.blue[700],
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    // Бонусные продажи
                                                    if (outlet.bonusQuantity > 0)
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.orange[50],
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            '${outlet.bonusQuantity} шт. (${outlet.bonusAmount.toStringAsFixed(2)} ₸)',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.orange[700],
                                                            ),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                        ),
                                                      ),
                                                    const SizedBox(width: 4),
                                                    // Общая сумма
                                                    Expanded(
                                                      child: Text(
                                                        'Итого: ${outlet.totalAmount.toStringAsFixed(2)} ₸',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        textAlign: TextAlign.end,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          )).toList(),
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                  // Список накладных
                                  if (productData.invoices.isNotEmpty) ...[
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
                                          ...productData.invoices.map((invoice) => Padding(
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

