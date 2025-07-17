import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../models/sales_rep.dart';
import '../services/firebase_service.dart';
import 'invoice_screen.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

class AdminIncomingInvoicesScreen extends StatefulWidget {
  final bool forSales;
  const AdminIncomingInvoicesScreen({Key? key, this.forSales = false}) : super(key: key);
  @override
  _AdminIncomingInvoicesScreenState createState() => _AdminIncomingInvoicesScreenState();
}

class _AdminIncomingInvoicesScreenState extends State<AdminIncomingInvoicesScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final FirebaseService _firebaseService = FirebaseService();
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  List<SalesRep> _salesReps = [];
  bool _isLoading = true;
  String? _selectedSalesRepId;
  String? _selectedPaymentStatus; // 'all', 'paid', 'not_paid', 'debt'
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      List<Invoice> invoices;
      if (widget.forSales) {
        final user = await AuthService().getCurrentUser();
        if (user == null) throw Exception('Пользователь не найден');
        print('[AdminIncomingInvoicesScreen] Текущий пользователь: uid=${user.uid}, role=${user.role}');
        invoices = await _invoiceService.getInvoicesByStatusAndSalesRepSimple('на рассмотрении', user.uid);
      } else {
        invoices = await _invoiceService.getInvoicesByStatus('на рассмотрении');
      }
      final salesReps = await _firebaseService.getSalesReps();
      setState(() {
        _invoices = invoices;
        _filteredInvoices = invoices;
        _salesReps = salesReps;
        _isLoading = false;
      });
      
      // Добавляем отладочную информацию
      print('[AdminIncomingInvoicesScreen] Загружено накладных: ${invoices.length}');
      for (var invoice in invoices) {
        print('[AdminIncomingInvoicesScreen] Накладная ${invoice.id}: статус = ${invoice.status}');
      }
      
      debugPrint('[AdminIncomingInvoicesScreen] Загружено накладных: "${invoices.length.toString()}"');
    } catch (e, st) {
      debugPrint('[AdminIncomingInvoicesScreen] Ошибка: $e\n$st');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterInvoices() {
    List<Invoice> filtered = _invoices;
    if (_selectedSalesRepId != null && _selectedSalesRepId != 'all') {
      filtered = filtered.where((inv) => inv.salesRepId == _selectedSalesRepId).toList();
    }
    if (_selectedPaymentStatus != null && _selectedPaymentStatus != 'all') {
      if (_selectedPaymentStatus == 'paid') {
        filtered = filtered.where((inv) => inv.isPaid).toList();
      } else if (_selectedPaymentStatus == 'not_paid') {
        filtered = filtered.where((inv) => !inv.isPaid && !inv.isDebt).toList();
      } else if (_selectedPaymentStatus == 'debt') {
        filtered = filtered.where((inv) => inv.isDebt).toList();
      }
    }
    if (_dateFrom != null) {
      filtered = filtered.where((inv) => inv.date.toDate().isAfter(_dateFrom!) || inv.date.toDate().isAtSameMomentAs(_dateFrom!)).toList();
    }
    if (_dateTo != null) {
      filtered = filtered.where((inv) => inv.date.toDate().isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
    }
    setState(() {
      _filteredInvoices = filtered;
    });
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
      _filterInvoices();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSalesRepId = null;
      _selectedPaymentStatus = null;
      _dateFrom = null;
      _dateTo = null;
      _filteredInvoices = _invoices;
    });
  }

  void _showConfirmDialog(Invoice invoice) {
    if (!widget.forSales) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Принять накладную?'),
          content: Text('Вы уверены, что хотите принять накладную №${invoice.id}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _invoiceService.updateInvoiceStatus(invoice.id, 'на сборке');
                _loadData();
              },
              child: Text('Принять'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Входящие накладные'), actions: [
        IconButton(icon: Icon(Icons.clear), onPressed: _clearFilters)
      ]),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Ошибка: \n$_errorMessage'))
              : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      DropdownButton<String>(
                        value: _selectedSalesRepId,
                        hint: Text('Торговый'),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text('Все')),
                          ..._salesReps.map((rep) => DropdownMenuItem(value: rep.id, child: Text(rep.name)))
                        ],
                        onChanged: (val) {
                          setState(() { _selectedSalesRepId = val; });
                          _filterInvoices();
                        },
                      ),
                      DropdownButton<String>(
                        value: _selectedPaymentStatus,
                        hint: Text('Оплата'),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text('Все')),
                          DropdownMenuItem(value: 'paid', child: Text('Оплачен')),
                          DropdownMenuItem(value: 'not_paid', child: Text('Не оплачен')),
                          DropdownMenuItem(value: 'debt', child: Text('Долг')),
                        ],
                        onChanged: (val) {
                          setState(() { _selectedPaymentStatus = val; });
                          _filterInvoices();
                        },
                      ),
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
                Expanded(
                  child: _filteredInvoices.isEmpty
                      ? Center(child: Text('Нет входящих накладных'))
                      : ListView.builder(
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _filteredInvoices[index];
                            return ListTile(
                              title: Text('Накладная №${invoice.id}'),
                              subtitle: Text('Точка: ${invoice.outletName}\nТорговый: ${invoice.salesRepName}'),
                              trailing: widget.forSales
                                  ? null
                                  : ElevatedButton(
                                child: Text('Принять'),
                                onPressed: () => _showConfirmDialog(invoice),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceScreen(invoiceId: invoice.id),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
} 