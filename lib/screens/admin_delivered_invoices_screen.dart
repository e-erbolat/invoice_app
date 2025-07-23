import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../models/sales_rep.dart';
import '../services/firebase_service.dart';
import 'invoice_screen.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

class AdminDeliveredInvoicesScreen extends StatefulWidget {
  final bool forSales;
  const AdminDeliveredInvoicesScreen({Key? key, this.forSales = false}) : super(key: key);
  @override
  _AdminDeliveredInvoicesScreenState createState() => _AdminDeliveredInvoicesScreenState();
}

class _AdminDeliveredInvoicesScreenState extends State<AdminDeliveredInvoicesScreen> {
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

  // Локальное состояние для сумм оплаты по каждой накладной
  final Map<String, double> _bankAmounts = {};
  final Map<String, double> _cashAmounts = {};
  final Map<String, bool> _isPaidMap = {};
  final Set<String> _selectedInvoiceIds = {};

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
        print('[AdminDeliveredInvoicesScreen] Текущий пользователь: uid=${user.uid}, role=${user.role}, salesRepId=${user.salesRepId}');
        if (user.salesRepId == null) throw Exception('У пользователя не заполнен salesRepId!');
        invoices = await _invoiceService.getInvoicesByStatusAndSalesRepSimple(InvoiceStatus.delivered, user.salesRepId!);
      } else {
        invoices = await _invoiceService.getInvoicesByStatus(InvoiceStatus.delivered);
      }
      final salesReps = await _firebaseService.getSalesReps();
      setState(() {
        _invoices = invoices;
        _filteredInvoices = invoices;
        _salesReps = salesReps;
        _isLoading = false;
      });
      
      // Добавляем отладочную информацию
      print('[AdminDeliveredInvoicesScreen] Загружено накладных: ${invoices.length}');
      for (var invoice in invoices) {
        print('[AdminDeliveredInvoicesScreen] Накладная ${invoice.id}: статус = ${invoice.status}');
      }
      
      debugPrint('[AdminDeliveredInvoicesScreen] Загружено накладных: "${invoices.length.toString()}"');
    } catch (e, st) {
      debugPrint('[AdminDeliveredInvoicesScreen] Ошибка: $e\n$st');
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

  void _showPaymentDialog(Invoice invoice) {
    double bankAmount = invoice.totalAmount;
    double cashAmount = 0.0;
    String comment = '';
    bool isPaid = invoice.isPaid;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final total = bankAmount + cashAmount;
          final isSumValid = (total - invoice.totalAmount).abs() < 0.01;
          return AlertDialog(
            title: Text('Принять оплату по накладной №${invoice.id}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Text('Банк:')),
                    SizedBox(
                      width: 100,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextFormField(
                          initialValue: bankAmount.toStringAsFixed(2),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                          onChanged: (val) {
                            setState(() {
                              bankAmount = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Text('Наличные:')),
                    SizedBox(
                      width: 100,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextFormField(
                          initialValue: cashAmount.toStringAsFixed(2),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                          onChanged: (val) {
                            setState(() {
                              cashAmount = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Итого: ${total.toStringAsFixed(2)} ₸ из ${invoice.totalAmount.toStringAsFixed(2)} ₸',
                  style: TextStyle(
                    color: isSumValid ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: comment,
                  decoration: InputDecoration(labelText: 'Комментарий'),
                  onChanged: (val) => comment = val,
                ),
                SwitchListTile(
                  title: Text('Оплачено'),
                  value: isPaid,
                  onChanged: (val) => setState(() { isPaid = val; }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: isSumValid && isPaid
                    ? () async {
                        Navigator.pop(context);
                        // paymentType: 'bank', 'cash', 'mixed'
                        String paymentType = (bankAmount > 0 && cashAmount > 0)
                            ? 'mixed'
                            : (bankAmount > 0)
                                ? 'bank'
                                : 'cash';
                        await _invoiceService.updateInvoicePayment(invoice.id, isPaid, paymentType, comment,
                            bankAmount: bankAmount, cashAmount: cashAmount);
                        if (isPaid) {
                          await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.delivered);
                        }
                        _loadData();
                      }
                    : null,
                child: Text('Принять оплату'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Доставленные накладные'), actions: [
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
                      child: Row(
                        children: [
                          // Чекбокс 'Выбрать все'
                          Checkbox(
                            value: _filteredInvoices.isNotEmpty && _filteredInvoices.every((inv) => _selectedInvoiceIds.contains(inv.id)),
                            tristate: false,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedInvoiceIds.addAll(_filteredInvoices.map((inv) => inv.id));
                                } else {
                                  _selectedInvoiceIds.removeAll(_filteredInvoices.map((inv) => inv.id));
                                }
                              });
                            },
                          ),
                          Text('Выбрано: ${_selectedInvoiceIds.length} из ${_filteredInvoices.length}', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Expanded(
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
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final selected = _filteredInvoices.where((inv) => _selectedInvoiceIds.contains(inv.id)).toList();
                              bool allValid = selected.isNotEmpty && selected.every((inv) {
                                final bank = _bankAmounts[inv.id] ?? inv.totalAmount;
                                final cash = _cashAmounts[inv.id] ?? 0.0;
                                return (bank + cash - inv.totalAmount).abs() < 0.01;
                              });
                              final totalBank = selected.fold<double>(0.0, (sum, inv) => sum + (_bankAmounts[inv.id] ?? inv.totalAmount));
                              final totalCash = selected.fold<double>(0.0, (sum, inv) => sum + (_cashAmounts[inv.id] ?? 0.0));
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed: allValid
                                        ? () async {
                                            for (final inv in selected) {
                                              final bank = _bankAmounts[inv.id] ?? inv.totalAmount;
                                              final cash = _cashAmounts[inv.id] ?? 0.0;
                                              await _invoiceService.updateInvoicePayment(
                                                inv.id,
                                                true,
                                                (bank > 0 && cash > 0)
                                                    ? 'mixed'
                                                    : (bank > 0)
                                                        ? 'bank'
                                                        : 'cash',
                                                '',
                                                bankAmount: bank,
                                                cashAmount: cash,
                                              );
                                              await _invoiceService.updateInvoiceStatus(inv.id, InvoiceStatus.delivered);
                                            }
                                            _loadData();
                                          }
                                        : null,
                                    child: Text('Принять все'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Банк: ${totalBank.toStringAsFixed(2)} ₸', style: TextStyle(fontWeight: FontWeight.w500)),
                                      Text('Наличные: ${totalCash.toStringAsFixed(2)} ₸', style: TextStyle(fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filteredInvoices.isEmpty
                          ? Center(child: Text('Нет доставленных накладных'))
                          : ListView.builder(
                              itemCount: _filteredInvoices.length,
                              itemBuilder: (context, index) {
                                final invoice = _filteredInvoices[index];
                                final date = invoice.date.toDate();
                                final dateStr = DateFormat('dd.MM.yyyy').format(date);
                                final dateNum = DateFormat('ddMMyyyy').format(date);
                                String suffix = '';
                                final idMatch = RegExp(r'(\d{4})$').firstMatch(invoice.id);
                                if (idMatch != null) {
                                  suffix = idMatch.group(1)!;
                                } else {
                                  suffix = (index + 1).toString().padLeft(4, '0');
                                }
                                final customNumber = '$dateNum-$suffix';
                                final isSelected = _selectedInvoiceIds.contains(invoice.id);
                                final bgColor = isSelected
                                    ? const Color(0xFFEDE7F6) // светло-фиолетовый
                                    : index % 2 == 0 ? Colors.white : Colors.grey.shade100;
                                return Container(
                                  color: bgColor,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Чекбокс выбора
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8, right: 0, top: 16),
                                        child: Checkbox(
                                          value: _selectedInvoiceIds.contains(invoice.id),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedInvoiceIds.add(invoice.id);
                                              } else {
                                                _selectedInvoiceIds.remove(invoice.id);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      // Левая часть: информация о накладной
                                      Expanded(
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                          leading: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                          title: Text('Накладная $customNumber'),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Точка: ${invoice.outletName}'),
                                              Text('Адрес: ${invoice.outletAddress}'),
                                              Text('Торговый: ${invoice.salesRepName}'),
                                            ],
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => InvoiceScreen(invoiceId: invoice.id),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      // Правая часть: оплата и кнопка
                                      Container(
                                        width: 220,
                                        padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text('Банк:', style: TextStyle(fontWeight: FontWeight.w500)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 90,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: TextFormField(
                                                      initialValue: _bankAmounts[invoice.id]?.toStringAsFixed(2) ?? invoice.totalAmount.toStringAsFixed(2),
                                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                      textAlign: TextAlign.left,
                                                      decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                                      onChanged: (val) {
                                                        setState(() {
                                                          _bankAmounts[invoice.id] = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text('Наличные:', style: TextStyle(fontWeight: FontWeight.w500)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 90,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: TextFormField(
                                                      initialValue: _cashAmounts[invoice.id]?.toStringAsFixed(2) ?? '0.00',
                                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                      textAlign: TextAlign.left,
                                                      decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                                      onChanged: (val) {
                                                        setState(() {
                                                          _cashAmounts[invoice.id] = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Builder(
                                              builder: (context) {
                                                final bank = _bankAmounts[invoice.id] ?? invoice.totalAmount;
                                                final cash = _cashAmounts[invoice.id] ?? 0.0;
                                                final total = bank + cash;
                                                final isSumValid = (total - invoice.totalAmount).abs() < 0.01;
                                                return Row(
                                                  children: [
                                                    Text('Итого:', style: TextStyle(fontWeight: FontWeight.w500)),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${total.toStringAsFixed(2)} ₸',
                                                      style: TextStyle(
                                                        color: isSumValid ? Colors.green : Colors.red,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(' из ${invoice.totalAmount.toStringAsFixed(2)} ₸'),
                                                  ],
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 12),
                                            Builder(
                                              builder: (context) {
                                                final bank = _bankAmounts[invoice.id] ?? invoice.totalAmount;
                                                final cash = _cashAmounts[invoice.id] ?? 0.0;
                                                final total = bank + cash;
                                                final isSumValid = (total - invoice.totalAmount).abs() < 0.01;
                                                return ElevatedButton(
                                                  child: Text('Принять оплату'),
                                                  onPressed: _selectedInvoiceIds.contains(invoice.id) && isSumValid
                                                      ? () async {
                                                          await _invoiceService.updateInvoicePayment(
                                                            invoice.id,
                                                            true,
                                                            (bank > 0 && cash > 0)
                                                                ? 'mixed'
                                                                : (bank > 0)
                                                                    ? 'bank'
                                                                    : 'cash',
                                                            '',
                                                            bankAmount: bank,
                                                            cashAmount: cash,
                                                          );
                                                          await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.delivered);
                                                          _loadData();
                                                        }
                                                      : null,
                                                );
                                              },
                                            ),
                                          ],
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
} 