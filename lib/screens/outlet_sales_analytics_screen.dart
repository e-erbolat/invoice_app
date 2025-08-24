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

  /// Выбор диапазона дат
  Future<void> _selectDateRange() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => DateRangePickerDialog(
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result['start']!;
        _endDate = result['end']!;
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
                : const Icon(Icons.table_chart),
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
                            onTap: _selectDateRange,
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
                                    '${DateFormat('dd.MM.yyyy').format(_startDate)} - ${DateFormat('dd.MM.yyyy').format(_endDate)}',
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

/// Кастомный диалог для выбора диапазона дат
class DateRangePickerDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const DateRangePickerDialog({
    Key? key,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  State<DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<DateRangePickerDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _currentMonth;
  bool _isSelectingStart = true; // true - выбираем начало, false - выбираем конец

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _currentMonth = DateTime(widget.startDate.year, widget.startDate.month);
    _isSelectingStart = true;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      if (_isSelectingStart) {
        // Выбираем первую дату
        _startDate = date;
        _endDate = date;
        _isSelectingStart = false;
      } else {
        // Выбираем вторую дату
        if (date.isBefore(_startDate)) {
          // Если вторая дата раньше первой, меняем местами
          _endDate = _startDate;
          _startDate = date;
        } else {
          _endDate = date;
        }
        _isSelectingStart = true; // Следующий клик сбросит выбор
      }
    });
  }

  void _resetSelection() {
    setState(() {
      _startDate = widget.startDate;
      _endDate = widget.endDate;
      _isSelectingStart = true;
    });
  }

  bool _isInRange(DateTime date) {
    return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
           date.isBefore(_endDate.add(const Duration(days: 1)));
  }

  bool _isStartDate(DateTime date) {
    return date.year == _startDate.year &&
           date.month == _startDate.month &&
           date.day == _startDate.day;
  }

  bool _isEndDate(DateTime date) {
    return date.year == _endDate.year &&
           date.month == _endDate.month &&
           date.day == _endDate.day;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Выберите период',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Навигация по месяцам
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Инструкция
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSelectingStart ? Colors.blue.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSelectingStart ? Colors.blue.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSelectingStart ? Icons.play_arrow : Icons.stop,
                    color: _isSelectingStart ? Colors.blue : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isSelectingStart 
                          ? 'Выберите дату начала периода'
                          : 'Выберите дату окончания периода',
                      style: TextStyle(
                        color: _isSelectingStart ? Colors.blue.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Календарь
            _buildCalendar(_currentMonth),
            
            const SizedBox(height: 16),
            
            // Выбранный диапазон
            if (_startDate != _endDate) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Выбранный период:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_endDate.difference(_startDate).inDays + 1} дней',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Кнопки действий
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _resetSelection,
                  child: const Text('Сбросить'),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop({
                          'start': _startDate,
                          'end': _endDate,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Применить'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    
    final weeks = <List<DateTime>>[];
    List<DateTime> currentWeek = [];
    
    // Добавляем пустые дни в начале месяца
    for (int i = 1; i < firstWeekday; i++) {
      currentWeek.add(DateTime(month.year, month.month - 1, 0));
    }
    
    // Добавляем дни месяца
    for (int day = 1; day <= daysInMonth; day++) {
      currentWeek.add(DateTime(month.year, month.month, day));
      
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }
    
    // Добавляем пустые дни в конце месяца
    while (currentWeek.length < 7) {
      currentWeek.add(DateTime(month.year, month.month + 1, currentWeek.length + 1));
    }
    if (currentWeek.isNotEmpty) {
      weeks.add(currentWeek);
    }
    
    return Column(
      children: [
        // Дни недели
        Row(
          children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) => 
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          ).toList(),
        ),
        
        // Календарная сетка
        ...weeks.map((week) => Row(
          children: week.map((date) {
            final isCurrentMonth = date.month == month.month;
            final isInRange = _isInRange(date);
            final isStart = _isStartDate(date);
            final isEnd = _isEndDate(date);
            
            return Expanded(
              child: Container(
                margin: const EdgeInsets.all(1),
                child: InkWell(
                  onTap: isCurrentMonth ? () => _selectDate(date) : null,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getDateColor(date, isCurrentMonth, isInRange, isStart, isEnd),
                      borderRadius: BorderRadius.circular(4),
                      border: isStart || isEnd
                          ? Border.all(color: Colors.blue, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isStart || isEnd ? FontWeight.bold : FontWeight.normal,
                          color: _getDateTextColor(date, isCurrentMonth, isInRange, isStart, isEnd),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        )).toList(),
      ],
    );
  }

  Color _getDateColor(DateTime date, bool isCurrentMonth, bool isInRange, bool isStart, bool isEnd) {
    if (!isCurrentMonth) return Colors.transparent;
    if (isStart || isEnd) return Colors.blue;
    if (isInRange) return Colors.blue.shade100;
    return Colors.transparent;
  }

  Color _getDateTextColor(DateTime date, bool isCurrentMonth, bool isInRange, bool isStart, bool isEnd) {
    if (!isCurrentMonth) return Colors.grey.shade400;
    if (isStart || isEnd) return Colors.white;
    if (isInRange) return Colors.blue.shade800;
    return Colors.black87;
  }

  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

