import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sales_rep.dart';
import '../models/outlet.dart';
import '../models/invoice.dart';
import '../services/firebase_service.dart';
import '../services/invoice_service.dart';

class SalesAnalysisScreen extends StatefulWidget {
  const SalesAnalysisScreen({Key? key}) : super(key: key);

  @override
  _SalesAnalysisScreenState createState() => _SalesAnalysisScreenState();
}

class _SalesAnalysisScreenState extends State<SalesAnalysisScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final InvoiceService _invoiceService = InvoiceService();
  
  List<SalesRep> _salesReps = [];
  SalesRep? _selectedSalesRep;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Результаты анализа
  int _newOutletsCount = 0;
  double _totalSalesAmount = 0.0;
  List<Outlet> _newOutlets = [];
  List<Invoice> _salesInvoices = [];

  @override
  void initState() {
    super.initState();
    _loadSalesReps();
    // Устанавливаем период по умолчанию - текущий месяц
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _loadSalesReps() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final salesReps = await _firebaseService.getSalesReps();
      setState(() {
        _salesReps = salesReps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки торговых: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _analyzeSales() async {
    if (_selectedSalesRep == null || _startDate == null || _endDate == null) {
      setState(() {
        _errorMessage = 'Выберите торгового и период для анализа';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Получаем всех клиентов, созданных выбранным торговым
      final allOutlets = await _firebaseService.getOutlets();
      final outletsCreatedBySalesRep = allOutlets.where((outlet) {
        return outlet.creatorId == _selectedSalesRep!.id &&
               outlet.createdAt.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();

      // 2. Получаем все накладные за период
      final allInvoices = await _invoiceService.getAllInvoices();
      final periodInvoices = allInvoices.where((invoice) {
        final invoiceDate = invoice.date.toDate();
        return invoiceDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
               invoiceDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();

      // 3. Находим новые точки (клиенты с первым заказом в периоде)
      final newOutlets = <Outlet>[];
      for (final outlet in outletsCreatedBySalesRep) {
        // Ищем первый заказ этого клиента
        final clientInvoices = periodInvoices.where((invoice) => 
          invoice.outletId == outlet.id
        ).toList();
        
        if (clientInvoices.isNotEmpty) {
          // Сортируем по дате и берем самый ранний
          clientInvoices.sort((a, b) => a.date.compareTo(b.date));
          final firstInvoice = clientInvoices.first;
          final firstInvoiceDate = firstInvoice.date.toDate();
          
          // Проверяем, что первый заказ в выбранном периоде
          if (firstInvoiceDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
              firstInvoiceDate.isBefore(_endDate!.add(const Duration(days: 1)))) {
            newOutlets.add(outlet);
          }
        }
      }

      // 4. Подсчитываем общую сумму продаж торгового за период
      final salesInvoices = periodInvoices.where((invoice) => 
        invoice.salesRepId == _selectedSalesRep!.id
      ).toList();
      
      final totalSalesAmount = salesInvoices.fold<double>(
        0.0, 
        (sum, invoice) => sum + invoice.totalAmount
      );

      setState(() {
        _newOutletsCount = newOutlets.length;
        _totalSalesAmount = totalSalesAmount;
        _newOutlets = newOutlets;
        _salesInvoices = salesInvoices;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка анализа: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Анализ работы торговых'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Выбор торгового
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Выберите торгового:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<SalesRep>(
                                value: _selectedSalesRep,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Выберите торгового',
                                ),
                                items: _salesReps.map((salesRep) {
                                  return DropdownMenuItem<SalesRep>(
                                    value: salesRep,
                                    child: Text(salesRep.name),
                                  );
                                }).toList(),
                                onChanged: (SalesRep? value) {
                                  setState(() {
                                    _selectedSalesRep = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Выбор периода
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Выберите период:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _selectDate(context, true),
                                      icon: const Icon(Icons.calendar_today),
                                      label: Text(
                                        _startDate != null 
                                          ? DateFormat('dd.MM.yyyy').format(_startDate!)
                                          : 'Начальная дата',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text('—', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _selectDate(context, false),
                                      icon: const Icon(Icons.calendar_today),
                                      label: Text(
                                        _endDate != null 
                                          ? DateFormat('dd.MM.yyyy').format(_endDate!)
                                          : 'Конечная дата',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Кнопка анализа
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _selectedSalesRep != null && _startDate != null && _endDate != null
                              ? _analyzeSales
                              : null,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Анализировать'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Результаты анализа
                      if (_selectedSalesRep != null && _newOutletsCount > 0 || _totalSalesAmount > 0) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Результаты анализа для ${_selectedSalesRep!.name}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                
                                // Количество новых точек
                                Row(
                                  children: [
                                    const Icon(Icons.store, color: Colors.green, size: 32),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Новых точек открыто:',
                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                        Text(
                                          '$_newOutletsCount',
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Общая сумма продаж
                                Row(
                                  children: [
                                    const Icon(Icons.attach_money, color: Colors.blue, size: 32),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Общая сумма продаж:',
                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                        Text(
                                          '${NumberFormat('#,##0.00', 'ru_RU').format(_totalSalesAmount)} ₸',
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Детали новых точек
                                if (_newOutlets.isNotEmpty) ...[
                                  const Text(
                                    'Детали новых точек:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  ...(_newOutlets.map((outlet) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: const Icon(Icons.store, color: Colors.green),
                                      title: Text(outlet.name),
                                      subtitle: Text(outlet.address),
                                      trailing: Text(
                                        DateFormat('dd.MM.yyyy').format(outlet.createdAt),
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ))),
                                ],
                                
                                const SizedBox(height: 16),
                                
                                // Статистика по накладным
                                if (_salesInvoices.isNotEmpty) ...[
                                  const Text(
                                    'Статистика по накладным:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Количество накладных: ${_salesInvoices.length}'),
                                  Text('Средняя сумма накладной: ${NumberFormat('#,##0.00', 'ru_RU').format(_totalSalesAmount / _salesInvoices.length)} ₸'),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
