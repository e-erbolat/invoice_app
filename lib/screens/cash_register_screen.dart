import 'package:flutter/material.dart';
import '../models/cash_register.dart';
import '../services/cash_register_service.dart';
import '../services/invoice_service.dart';
import '../models/invoice.dart';
import 'invoice_screen.dart';
import 'package:intl/intl.dart';

class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({Key? key}) : super(key: key);

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> {
  final CashRegisterService _cashRegisterService = CashRegisterService();
  final InvoiceService _invoiceService = InvoiceService();
  List<CashRegister> _cashRecords = [];
  Map<String, Invoice?> _invoiceCache = {}; // Кэш для накладных
  bool _isLoading = true;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final records = await _cashRegisterService.getCashHistory(
        fromDate: _dateFrom,
        toDate: _dateTo,
      );
      final total = await _cashRegisterService.getTotalCashAmount();
      
      // Загружаем информацию о накладных для отображения названий магазинов
      _invoiceCache.clear();
      for (final record in records) {
        if (record.invoiceId != null && !_invoiceCache.containsKey(record.invoiceId)) {
          try {
            final invoice = await _invoiceService.getInvoiceById(record.invoiceId!);
            _invoiceCache[record.invoiceId!] = invoice;
          } catch (e) {
            // Если накладная не найдена, оставляем null
            _invoiceCache[record.invoiceId!] = null;
          }
        }
      }
      
      setState(() {
        _cashRecords = records;
        _totalAmount = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке данных: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now()),
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      _loadData();
    }
  }

  void _clearFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Касса'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: _clearFilters,
            tooltip: 'Сбросить фильтры',
          ),
        ],
      ),
      body: Column(
        children: [
          // Фильтры
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _selectDate(context, true),
                        child: Text(_dateFrom == null ? 'С даты' : DateFormat('dd.MM.yyyy').format(_dateFrom!)),
                      ),
                      OutlinedButton(
                        onPressed: () => _selectDate(context, false),
                        child: Text(_dateTo == null ? 'По дату' : DateFormat('dd.MM.yyyy').format(_dateTo!)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    'Итого: ${_totalAmount.toStringAsFixed(2)} ₸',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Список записей
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _cashRecords.isEmpty
                    ? Center(child: Text('Нет записей в кассе'))
                    : ListView.builder(
                        itemCount: _cashRecords.length,
                        itemBuilder: (context, index) {
                          final record = _cashRecords[index];
                          final isPositive = record.amount > 0;
                          final invoice = record.invoiceId != null ? _invoiceCache[record.invoiceId] : null;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPositive ? Colors.green : Colors.red,
                                child: Icon(
                                  isPositive ? Icons.add : Icons.remove,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                record.description ?? 'Операция',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('dd.MM.yyyy HH:mm').format(record.date)),
                                  if (invoice != null) ...[
                                    Text('Магазин: ${invoice.outletName}'),
                                    if (invoice.outletAddress.isNotEmpty)
                                      Text('Адрес: ${invoice.outletAddress}'),
                                  ],
                                  if (record.invoiceId != null)
                                    Text('Накладная: ${record.invoiceId}'),
                                ],
                              ),
                              trailing: Text(
                                '${isPositive ? '+' : ''}${record.amount.toStringAsFixed(2)} ₸',
                                style: TextStyle(
                                  color: isPositive ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onTap: record.invoiceId != null ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceScreen(invoiceId: record.invoiceId!),
                                  ),
                                );
                              } : null,
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