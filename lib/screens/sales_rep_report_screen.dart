import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../models/sales_rep.dart';
import '../services/firebase_service.dart';
import '../services/invoice_service.dart';
import 'package:intl/intl.dart';

class SalesRepReportScreen extends StatefulWidget {
  const SalesRepReportScreen({super.key});

  @override
  State<SalesRepReportScreen> createState() => _SalesRepReportScreenState();
}

class _SalesRepReportScreenState extends State<SalesRepReportScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final InvoiceService _invoiceService = InvoiceService();
  
  List<SalesRep> _salesReps = [];
  List<Invoice> _invoices = [];
  Map<String, List<Invoice>> _salesRepInvoices = {};
  Map<String, double> _salesRepTotals = {};
  
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
      final salesReps = await _firebaseService.getSalesReps();
      final invoices = await _invoiceService.getAllInvoices();
      
      setState(() {
        _salesReps = salesReps;
        _invoices = invoices;
        _isLoading = false;
      });
      
      _calculateSalesRepStats();
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

  void _calculateSalesRepStats() {
    final Map<String, List<Invoice>> salesRepInvoices = {};
    final Map<String, double> salesRepTotals = {};

    // Группируем накладные по торговым представителям
    for (final invoice in _invoices) {
      if (!salesRepInvoices.containsKey(invoice.salesRepId)) {
        salesRepInvoices[invoice.salesRepId] = [];
      }
      salesRepInvoices[invoice.salesRepId]!.add(invoice);
    }

    // Рассчитываем общие суммы для каждого представителя
    for (final salesRep in _salesReps) {
      final invoices = salesRepInvoices[salesRep.id] ?? [];
      final total = invoices.fold(0.0, (total, invoice) => total + invoice.totalAmount);
      salesRepTotals[salesRep.id] = total;
    }

    setState(() {
      _salesRepInvoices = salesRepInvoices;
      _salesRepTotals = salesRepTotals;
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
                  _calculateSalesRepStats();
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
                  _calculateSalesRepStats();
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
                  _calculateSalesRepStats();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Invoice> _getFilteredInvoices(String salesRepId) {
    var invoices = _salesRepInvoices[salesRepId] ?? [];
    
    if (_startDate != null && _endDate != null) {
      invoices = invoices.where((invoice) {
        final invoiceDate = invoice.date.toDate();
        return invoiceDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
               invoiceDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }
    
    return invoices;
  }

  double _getSalesRepTotal(String salesRepId) {
    final invoices = _getFilteredInvoices(salesRepId);
    return invoices.fold(0.0, (total, invoice) => total + invoice.totalAmount);
  }

  List<SalesRep> _getSortedSalesReps() {
    final sortedReps = List<SalesRep>.from(_salesReps);
    sortedReps.sort((a, b) {
      final totalA = _getSalesRepTotal(a.id);
      final totalB = _getSalesRepTotal(b.id);
      return totalB.compareTo(totalA); // Сортировка по убыванию
    });
    return sortedReps;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Отчёт по торговым представителям')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sortedSalesReps = _getSortedSalesReps();
    final totalRevenue = _salesReps.fold(0.0, (total, rep) => total + _getSalesRepTotal(rep.id));
    final activeReps = _salesReps.where((rep) => _getSalesRepTotal(rep.id) > 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчёт по торговым представителям'),
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
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Всего представителей',
                  _salesReps.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Активных представителей',
                  activeReps.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  'Общая выручка',
                  '${totalRevenue.toStringAsFixed(2)} ₸',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ],
            ),
          ),
          
          // Топ представителей
          if (sortedSalesReps.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text(
                    'Топ представителей',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          // Список торговых представителей
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sortedSalesReps.length,
              itemBuilder: (context, index) {
                final salesRep = sortedSalesReps[index];
                final total = _getSalesRepTotal(salesRep.id);
                final invoices = _getFilteredInvoices(salesRep.id);
                final rank = index + 1;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getRankColor(rank),
                      child: rank <= 3 
                        ? Icon(Icons.emoji_events, color: Colors.white)
                        : Text(
                            rank.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            salesRep.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (rank <= 3)
                          Icon(
                            Icons.emoji_events,
                            color: _getRankColor(rank),
                            size: 20,
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${invoices.length} накладных • ${total.toStringAsFixed(2)} ₸',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${total.toStringAsFixed(2)} ₸',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Ранг #$rank',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                                '${DateFormat('dd.MM.yyyy').format(invoice.date.toDate())} • ${invoice.outletName}',
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

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.brown.shade300;
      default:
        return Colors.blue;
    }
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