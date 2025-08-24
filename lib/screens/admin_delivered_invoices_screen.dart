import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../models/sales_rep.dart';
import '../services/firebase_service.dart';
import 'invoice_screen.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/excel_export_service.dart';
import 'package:share_plus/share_plus.dart';
import 'invoice_create_screen.dart';

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
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _errorMessage;
  String _sortField = 'date'; // 'date', 'name', 'amount'
  bool _sortAscending = false; // false = новые сначала

  // Локальное состояние для сумм оплаты по каждой накладной
  final Map<String, double> _bankAmounts = {};
  final Map<String, double> _cashAmounts = {};
  final Map<String, bool> _isPaidMap = {};
  final Set<String> _selectedInvoiceIds = {};
  // Контроллеры для полей ввода
  final Map<String, TextEditingController> _bankControllers = {};
  final Map<String, TextEditingController> _cashControllers = {};
  // Сохраненные значения для отмены изменений
  final Map<String, double> _originalBankAmounts = {};
  final Map<String, double> _originalCashAmounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Очищаем все контроллеры
    _bankControllers.values.forEach((controller) => controller.dispose());
    _cashControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      List<Invoice> invoices;
      if (widget.forSales) {
        final user = await AuthService().getCurrentUser();
        if (user == null) throw Exception('Пользователь не найден');
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
    } catch (e, st) {
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

    if (_dateFrom != null) {
      filtered = filtered.where((inv) => inv.date.toDate().isAfter(_dateFrom!) || inv.date.toDate().isAtSameMomentAs(_dateFrom!)).toList();
    }
    if (_dateTo != null) {
      filtered = filtered.where((inv) => inv.date.toDate().isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
    }
    
    // Сортировка
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortField) {
        case 'date':
          comparison = a.date.compareTo(b.date);
          break;
        case 'name':
          comparison = a.outletName.compareTo(b.outletName);
          break;
        case 'amount':
          comparison = a.totalAmount.compareTo(b.totalAmount);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    
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
      _dateFrom = null;
      _dateTo = null;
      _sortField = 'date';
      _sortAscending = false;
      _filteredInvoices = _invoices;
    });
    _filterInvoices();
  }

  String _getSortFieldText() {
    switch (_sortField) {
      case 'date':
        return 'Дата';
      case 'name':
        return 'Название';
      case 'amount':
        return 'Сумма';
      default:
        return 'Сортировать по';
    }
  }

  // Инициализация контроллеров для накладной
  void _initializeControllers(String invoiceId, double totalAmount) {
    if (!_bankControllers.containsKey(invoiceId)) {
      final bankAmount = _bankAmounts[invoiceId] ?? totalAmount;
      final cashAmount = _cashAmounts[invoiceId] ?? 0.0;
      
      _bankControllers[invoiceId] = TextEditingController(
        text: bankAmount.toStringAsFixed(2)
      );
      _cashControllers[invoiceId] = TextEditingController(
        text: cashAmount.toStringAsFixed(2)
      );
      
      // Сохраняем оригинальные значения
      _originalBankAmounts[invoiceId] = bankAmount;
      _originalCashAmounts[invoiceId] = cashAmount;
    }
  }
  
  // Обработчик фокуса для поля банка
  void _onBankFieldTap(String invoiceId) {
    final controller = _bankControllers[invoiceId];
    if (controller != null) {
      // Очищаем поле при нажатии
      controller.clear();
    }
  }
  
  // Обработчик фокуса для поля наличных
  void _onCashFieldTap(String invoiceId) {
    final controller = _cashControllers[invoiceId];
    if (controller != null) {
      // Очищаем поле при нажатии
      controller.clear();
    }
  }
  
  // Обработчик потери фокуса для поля банка
  void _onBankFieldUnfocus(String invoiceId) {
    final controller = _bankControllers[invoiceId];
    if (controller != null) {
      final text = controller.text.trim();
      if (text.isEmpty) {
        // Если поле пустое, возвращаем оригинальное значение
        final originalValue = _originalBankAmounts[invoiceId] ?? 0.0;
        controller.text = originalValue.toStringAsFixed(2);
        _bankAmounts[invoiceId] = originalValue;
      } else {
        // Если есть изменения, сохраняем новое значение
        final newValue = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
        _bankAmounts[invoiceId] = newValue;
        _originalBankAmounts[invoiceId] = newValue;
      }
    }
  }
  
  // Обработчик потери фокуса для поля наличных
  void _onCashFieldUnfocus(String invoiceId) {
    final controller = _cashControllers[invoiceId];
    if (controller != null) {
      final text = controller.text.trim();
      if (text.isEmpty) {
        // Если поле пустое, возвращаем оригинальное значение
        final originalValue = _originalCashAmounts[invoiceId] ?? 0.0;
        controller.text = originalValue.toStringAsFixed(2);
        _cashAmounts[invoiceId] = originalValue;
      } else {
        // Если есть изменения, сохраняем новое значение
        final newValue = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
        _cashAmounts[invoiceId] = newValue;
        _originalCashAmounts[invoiceId] = newValue;
      }
    }
  }

  void _showPaymentDialog(Invoice invoice) {
    double bankAmount = invoice.totalAmount;
    double cashAmount = 0.0;
    String comment = '';
    bool isPaid = true; // При принятии оплаты всегда устанавливаем в true
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: isSumValid
                    ? () async {
                        Navigator.pop(context);
                        // paymentType: 'bank', 'cash', 'mixed'
                        String paymentType = (bankAmount > 0 && cashAmount > 0)
                            ? 'mixed'
                            : (bankAmount > 0)
                                ? 'bank'
                                : 'cash';
                        await _invoiceService.updateInvoicePayment(invoice.id, paymentType, comment,
                            bankAmount: bankAmount, cashAmount: cashAmount);
                        await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.paymentChecked);
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

  bool _isExporting = false;

  void _exportInvoicesToExcel() async {
    if (_isExporting) return; // Защита от множественных нажатий
    
    setState(() {
      _isExporting = true;
    });
    
    try {
      await ExcelExportService.exportInvoicesToExcel(
        invoices: _filteredInvoices,
        sheetName: 'Доставленные накладные',
        fileName: 'delivered_invoices',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Доставленные накладные'),
        actions: [
          IconButton(
            icon: _isExporting 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.share),
            tooltip: 'Поделиться Excel',
            onPressed: _isExporting ? null : _exportInvoicesToExcel,
          ),
          if (!kIsWeb)
            IconButton(
              icon: Icon(Icons.filter_list),
              tooltip: 'Фильтры',
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => _FilterDialog(
                    forSales: widget.forSales,
                    salesReps: _salesReps,
                    selectedSalesRepId: _selectedSalesRepId,
                    onSalesRepChanged: (val) => setState(() => _selectedSalesRepId = val),
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    onDateFromChanged: (val) => setState(() => _dateFrom = val),
                    onDateToChanged: (val) => setState(() => _dateTo = val),
                    sortField: _sortField,
                    sortAscending: _sortAscending,
                    onSortChanged: (field, ascending) {
                      setState(() {
                        _sortField = field;
                        _sortAscending = ascending;
                      });
                    },
                    onClear: _clearFilters,
                    onApply: () {
                      _filterInvoices();
                      Navigator.pop(context);
                    },
                  ),
                );
                _filterInvoices();
              },
            ),
          IconButton(icon: Icon(Icons.clear), onPressed: _clearFilters)
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Ошибка: \n$_errorMessage'))
              : Column(
                  children: [
                    if (kIsWeb)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!widget.forSales) ...[
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
                                  ],
                                  OutlinedButton(
                                    onPressed: () => _selectDate(context, true),
                                    child: Text(_dateFrom == null ? 'С даты' : DateFormat('dd.MM.yyyy').format(_dateFrom!)),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _selectDate(context, false),
                                    child: Text(_dateTo == null ? 'По дату' : DateFormat('dd.MM.yyyy').format(_dateTo!)),
                                  ),
                                  // Кнопка сортировки с выпадающим списком
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: null, // Кнопка неактивна, только для отображения
                                        icon: Icon(Icons.sort),
                                        label: _sortField == 'date' || _sortField == 'name' || _sortField == 'amount'
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(_getSortFieldText()),
                                                SizedBox(width: 4),
                                                Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                                              ],
                                            )
                                          : Text('Сортировать по'),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.arrow_drop_down),
                                    onSelected: (value) {
                                      setState(() {
                                        if (value == 'date') {
                                          _sortField = 'date';
                                          _sortAscending = !_sortAscending;
                                        } else if (value == 'name') {
                                          _sortField = 'name';
                                          _sortAscending = !_sortAscending;
                                        } else if (value == 'amount') {
                                          _sortField = 'amount';
                                          _sortAscending = !_sortAscending;
                                        }
                                      });
                                      _filterInvoices();
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'date',
                                        child: Row(
                                          children: [
                                            Text('Дата'),
                                            Spacer(),
                                            Icon(_sortField == 'date' 
                                              ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                              : Icons.unfold_more
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'name',
                                        child: Row(
                                          children: [
                                            Text('Название'),
                                            Spacer(),
                                            Icon(_sortField == 'name' 
                                              ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                              : Icons.unfold_more
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'amount',
                                        child: Row(
                                          children: [
                                            Text('Сумма'),
                                            Spacer(),
                                            Icon(_sortField == 'amount' 
                                              ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                              : Icons.unfold_more
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     child: Builder(
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
                           children: [
                             Spacer(),
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               children: [
                                 if (!widget.forSales)
                                   ElevatedButton(
                                     onPressed: allValid && selected.isNotEmpty
                                         ? () async {
                                           for (final inv in selected) {
                                             final bank = _bankAmounts[inv.id] ?? inv.totalAmount;
                                             final cash = _cashAmounts[inv.id] ?? 0.0;
                                             await _invoiceService.updateInvoicePayment(
                                               inv.id,
                                               (bank > 0 && cash > 0)
                                                   ? 'mixed'
                                                   : (bank > 0)
                                                       ? 'bank'
                                                       : 'cash',
                                               '',
                                               bankAmount: bank,
                                               cashAmount: cash,
                                             );
                                             await _invoiceService.updateInvoiceStatus(
                                               inv.id,
                                               InvoiceStatus.paymentChecked, // Переводим в статус "Проверка оплат"
                                             );
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
                                 if (!widget.forSales) ...[
                                   const SizedBox(height: 8),
                                   Text('Банк: ${totalBank.toStringAsFixed(2)} ₸', style: TextStyle(fontWeight: FontWeight.w500)),
                                   Text('Наличные: ${totalCash.toStringAsFixed(2)} ₸', style: TextStyle(fontWeight: FontWeight.w500)),
                                 ],
                               ],
                             ),
                           ],
                         );
                       },
                     ),
                   ),
                    Expanded(
                      child: _filteredInvoices.isEmpty
                          ? Center(child: Text('Нет доставленных накладных'))
                          : ListView.builder(
                              itemCount: _filteredInvoices.length,
                              itemBuilder: (context, index) {
                                final invoice = _filteredInvoices[index];
                                // Инициализируем контроллеры для этой накладной
                                _initializeControllers(invoice.id, invoice.totalAmount);
                                
                                // Добавляем общую сумму в начале для мобильных
                                if (index == 0 && !kIsWeb) {
                                  final totalSum = _filteredInvoices.fold<double>(
                                    0.0, (sum, inv) => sum + inv.totalAmount
                                  );
                                  return Column(
                                    children: [
                                      Container(
                                        margin: EdgeInsets.all(16),
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.deepPurple),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Общая сумма:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
                                              ),
                                            ),
                                            Text(
                                              '${totalSum.toStringAsFixed(2)} ₸',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildInvoiceItem(invoice, index),
                                    ],
                                  );
                                }
                                
                                return _buildInvoiceItem(invoice, index);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
 
  Widget _buildInvoiceItem(Invoice invoice, int index) {
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
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Чекбокс выбора (только для админа)
              if (!widget.forSales)
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
              // Правая часть: оплата (только для админа)
              if (!widget.forSales)
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
                              controller: _bankControllers[invoice.id],
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.left,
                              decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              onTap: () => _onBankFieldTap(invoice.id),
                              onEditingComplete: () => _onBankFieldUnfocus(invoice.id),
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
                              controller: _cashControllers[invoice.id],
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.left,
                              decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              onTap: () => _onCashFieldTap(invoice.id),
                              onEditingComplete: () => _onCashFieldUnfocus(invoice.id),
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
                                    (bank > 0 && cash > 0)
                                        ? 'mixed'
                                        : (bank > 0)
                                            ? 'bank'
                                            : 'cash',
                                    '',
                                    bankAmount: bank,
                                    cashAmount: cash,
                                  );
                                  await _invoiceService.updateInvoiceStatus(
                                    invoice.id,
                                    InvoiceStatus.paymentChecked, // Переводим в статус "Проверка оплат"
                                  );
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
          // Кнопки действий внизу для мобильных устройств (только для админа)
          if (!kIsWeb && !widget.forSales) ...[
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InvoiceCreateScreen(invoiceToEdit: invoice),
                          ),
                        ).then((_) => _loadData());
                      },
                      icon: Icon(Icons.edit, color: Colors.white),
                      label: Text('Редактировать'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Удалить накладную?'),
                            content: Text('Вы уверены, что хотите удалить накладную?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Отмена'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: Text('Удалить'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _invoiceService.deleteInvoice(invoice.id);
                          _loadData();
                        }
                      },
                      icon: Icon(Icons.delete, color: Colors.white),
                      label: Text('Удалить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final buffer = StringBuffer();
                        buffer.writeln('Накладная ${invoice.id}');
                        buffer.writeln('Точка: ${invoice.outletName}');
                        buffer.writeln('Адрес: ${invoice.outletAddress}');
                        buffer.writeln('Торговый: ${invoice.salesRepName}');
                        buffer.writeln('Сумма: ${invoice.totalAmount.toStringAsFixed(2)} ₸');
                        buffer.writeln('Статус: ${InvoiceStatus.getName(invoice.status)}');
                        Share.share(buffer.toString());
                      },
                      icon: Icon(Icons.share, color: Colors.white),
                      label: Text('Поделиться'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
} 

// Вспомогательный диалог фильтров
class _FilterDialog extends StatelessWidget {
  final bool forSales;
  final List<SalesRep> salesReps;
  final String? selectedSalesRepId;
  final ValueChanged<String?> onSalesRepChanged;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final String sortField;
  final bool sortAscending;
  final Function(String field, bool ascending) onSortChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;
  const _FilterDialog({
    required this.forSales,
    required this.salesReps,
    required this.selectedSalesRepId,
    required this.onSalesRepChanged,
    required this.dateFrom,
    required this.dateTo,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.sortField,
    required this.sortAscending,
    required this.onSortChanged,
    required this.onClear,
    required this.onApply,
  });
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Фильтры'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!forSales) ...[
              DropdownButton<String>(
                value: selectedSalesRepId,
                hint: Text('Торговый'),
                items: [
                  DropdownMenuItem(value: 'all', child: Text('Все')),
                  ...salesReps.map((rep) => DropdownMenuItem(value: rep.id, child: Text(rep.name)))
                ],
                onChanged: onSalesRepChanged,
              ),
            ],
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dateFrom ?? DateTime.now(),
                  firstDate: DateTime(2022),
                  lastDate: DateTime(2100),
                );
                if (picked != null) onDateFromChanged(picked);
              },
              child: Text(dateFrom == null ? 'С даты' : DateFormat('dd.MM.yyyy').format(dateFrom!)),
            ),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dateTo ?? DateTime.now(),
                  firstDate: DateTime(2022),
                  lastDate: DateTime(2100),
                );
                if (picked != null) onDateToChanged(picked);
              },
              child: Text(dateTo == null ? 'По дату' : DateFormat('dd.MM.yyyy').format(dateTo!)),
            ),
            const SizedBox(height: 16),
            const Text('Сортировка:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: sortField,
              hint: Text('Выберите поле для сортировки'),
              items: [
                DropdownMenuItem(
                  value: 'date',
                  child: Row(
                    children: [
                      Text('Дата'),
                      Spacer(),
                      Icon(sortField == 'date' 
                        ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.unfold_more
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'name',
                  child: Row(
                    children: [
                      Text('Название'),
                      Spacer(),
                      Icon(sortField == 'name' 
                        ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.unfold_more
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'amount',
                  child: Row(
                    children: [
                      Text('Сумма'),
                      Spacer(),
                      Icon(sortField == 'amount' 
                        ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.unfold_more
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onSortChanged(value, sortField == value ? !sortAscending : false);
                }
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => onSortChanged(sortField, !sortAscending),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Изменить направление'),
                  Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onClear, child: Text('Сбросить фильтры')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена')),
        ElevatedButton(onPressed: onApply, child: Text('Применить')),
      ],
    );
  }
} 