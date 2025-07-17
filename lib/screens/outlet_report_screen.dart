import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../models/outlet.dart';
import '../services/firebase_service.dart';
import '../services/invoice_service.dart';
import 'package:intl/intl.dart';

class OutletReportScreen extends StatefulWidget {
  const OutletReportScreen({super.key});

  @override
  State<OutletReportScreen> createState() => _OutletReportScreenState();
}

class _OutletReportScreenState extends State<OutletReportScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final InvoiceService _invoiceService = InvoiceService();
  
  List<Outlet> _outlets = [];
  List<Invoice> _invoices = [];
  Map<String, List<Invoice>> _outletInvoices = {};
  Map<String, double> _outletTotals = {};
  
  bool _isLoading = true;
  String _selectedPeriod = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final outlets = await _firebaseService.getOutlets();
      final invoices = await _invoiceService.getAllInvoices();
      
      setState(() {
        _outlets = outlets;
        _invoices = invoices;
        _isLoading = false;
      });
      
      _calculateOutletStats();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  void _calculateOutletStats() {
    final Map<String, List<Invoice>> outletInvoices = {};
    final Map<String, double> outletTotals = {};

    // Группируем накладные по торговым точкам
    for (final invoice in _invoices) {
      if (!outletInvoices.containsKey(invoice.outletId)) {
        outletInvoices[invoice.outletId] = [];
      }
      outletInvoices[invoice.outletId]!.add(invoice);
    }

    // Рассчитываем общие суммы для каждой точки
    for (final outlet in _outlets) {
      final invoices = outletInvoices[outlet.id] ?? [];
      final total = invoices.fold(0.0, (total, invoice) => total + invoice.totalAmount);
      outletTotals[outlet.id] = total;
    }

    setState(() {
      _outletInvoices = outletInvoices;
      _outletTotals = outletTotals;
    });
  }

  void _filterByPeriod() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите период'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Все время'),
              leading: Radio<String>(
                value: 'all',
                groupValue: _selectedPeriod,
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value!;
                    _startDate = null;
                    _endDate = null;
                  });
                  Navigator.pop(context);
                  _calculateOutletStats();
                },
              ),
            ),
            ListTile(
              title: const Text('Этот месяц'),
              leading: Radio<String>(
                value: 'month',
                groupValue: _selectedPeriod,
                onChanged: (value) {
                  final now = DateTime.now();
                  setState(() {
                    _selectedPeriod = value!;
                    _startDate = DateTime(now.year, now.month, 1);
                    _endDate = DateTime(now.year, now.month + 1, 0);
                  });
                  Navigator.pop(context);
                  _calculateOutletStats();
                },
              ),
            ),
            ListTile(
              title: const Text('Этот год'),
              leading: Radio<String>(
                value: 'year',
                groupValue: _selectedPeriod,
                onChanged: (value) {
                  final now = DateTime.now();
                  setState(() {
                    _selectedPeriod = value!;
                    _startDate = DateTime(now.year, 1, 1);
                    _endDate = DateTime(now.year, 12, 31);
                  });
                  Navigator.pop(context);
                  _calculateOutletStats();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Invoice> _getFilteredInvoices(String outletId) {
    var invoices = _outletInvoices[outletId] ?? [];
    
    if (_startDate != null && _endDate != null) {
      invoices = invoices.where((invoice) {
        final invoiceDate = invoice.date.toDate();
        return invoiceDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
               invoiceDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }
    
    return invoices;
  }

  double _getOutletTotal(String outletId) {
    final invoices = _getFilteredInvoices(outletId);
    return invoices.fold(0.0, (total, invoice) => total + invoice.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Отчёт по торговым точкам')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчёт по торговым точкам'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _filterByPeriod,
            tooltip: 'Фильтр по периоду',
          ),
        ],
      ),
      body: Column(
        children: [
          // Период фильтрации
          if (_startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Период: ${DateFormat('dd.MM.yyyy').format(_startDate!)} - ${DateFormat('dd.MM.yyyy').format(_endDate!)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          
          // Общая статистика
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Всего точек',
                  _outlets.length.toString(),
                  Icons.store,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Активных точек',
                  _outlets.where((outlet) => _getOutletTotal(outlet.id) > 0).length.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  'Общая сумма',
                  '${_outlets.fold(0.0, (total, outlet) => total + _getOutletTotal(outlet.id)).toStringAsFixed(2)} ₸',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ],
            ),
          ),
          
          // Список торговых точек
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _outlets.length,
              itemBuilder: (context, index) {
                final outlet = _outlets[index];
                final total = _getOutletTotal(outlet.id);
                final invoices = _getFilteredInvoices(outlet.id);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: total > 0 ? Colors.green : Colors.grey,
                      child: Icon(
                        Icons.store,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      outlet.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${invoices.length} накладных • ${total.toStringAsFixed(2)} ₸',
                    ),
                    trailing: Text(
                      total > 0 ? 'Активна' : 'Неактивна',
                      style: TextStyle(
                        color: total > 0 ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      if (invoices.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: invoices.length,
                          itemBuilder: (context, invoiceIndex) {
                            final invoice = invoices[invoiceIndex];
                            return ListTile(
                              leading: const Icon(Icons.receipt),
                              title: Text('Накладная #${invoice.id.substring(invoice.id.length - 6)}'),
                              subtitle: Text(
                                '${DateFormat('dd.MM.yyyy').format(invoice.date.toDate())} • ${invoice.salesRepName}',
                              ),
                              trailing: Text(
                                '${invoice.totalAmount.toStringAsFixed(2)} ₸',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Нет накладных за выбранный период',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 