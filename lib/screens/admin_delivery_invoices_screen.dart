import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../models/sales_rep.dart';
import '../services/firebase_service.dart';
import 'invoice_screen.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

class AdminDeliveryInvoicesScreen extends StatefulWidget {
  final bool forSales;
  const AdminDeliveryInvoicesScreen({Key? key, this.forSales = false}) : super(key: key);
  @override
  _AdminDeliveryInvoicesScreenState createState() => _AdminDeliveryInvoicesScreenState();
}

class _AdminDeliveryInvoicesScreenState extends State<AdminDeliveryInvoicesScreen> {
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
        print('[AdminDeliveryInvoicesScreen] Текущий пользователь: uid=${user.uid}, role=${user.role}, salesRepId=${user.salesRepId}');
        if (user.salesRepId == null) throw Exception('У пользователя не заполнен salesRepId!');
        invoices = await _invoiceService.getInvoicesByStatusAndSalesRepSimple(InvoiceStatus.delivery, user.salesRepId!);
      } else {
        invoices = await _invoiceService.getInvoicesByStatus(InvoiceStatus.delivery);
      }
      final salesReps = await _firebaseService.getSalesReps();
      setState(() {
        _invoices = invoices;
        _filteredInvoices = invoices;
        _salesReps = salesReps;
        _isLoading = false;
      });
      debugPrint('[AdminDeliveryInvoicesScreen] Загружено накладных: "${invoices.length.toString()}"');
    } catch (e, st) {
      debugPrint('[AdminDeliveryInvoicesScreen] Ошибка: $e\n$st');
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
          title: Text('Архивировать накладную?'),
          content: Text('Вы уверены, что хотите архивировать накладную №${invoice.id}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.delivered);
                _loadData();
              },
              child: Text('Архивировать'),
            ),
          ],
        ),
      );
    }
  }

  void _exportInvoicesToExcel() async {
    if (_filteredInvoices.isEmpty) return;
    final excel = Excel.createExcel();
    final sheet = excel['Накладные на доставке'];
    final cellStyle = CellStyle(
      fontFamily: 'Times New Roman',
      fontSize: 25,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    int currentRow = 0;
    for (int invoiceIndex = 0; invoiceIndex < _filteredInvoices.length; invoiceIndex++) {
      final invoice = _filteredInvoices[invoiceIndex];
      // Заголовок накладной (строка 1)
      var cell1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      cell1.value = 'MELLO AQTOBE';
      cell1.cellStyle = cellStyle;
      var cell2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cell2.value = DateFormat('dd.MM.yyyy').format(invoice.date.toDate());
      cell2.cellStyle = cellStyle;
      currentRow++;
      // Заголовки таблицы (строка 2)
      for (int col = 0; col <= 5; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        switch (col) {
          case 0: cell.value = '№'; break;
          case 1: cell.value = 'Наименование товара'; break;
          case 2: cell.value = 'Цена по прайсу'; break;
          case 3: cell.value = 'Цена со скидкой'; break;
          case 4: cell.value = 'Количество'; break;
          case 5: cell.value = 'Итого'; break;
        }
        cell.cellStyle = cellStyle;
      }
      currentRow++;
      // Товары: сначала обычные, потом бонусные
      final nonBonusItems = invoice.items.where((item) => !item.isBonus).toList();
      final bonusItems = invoice.items.where((item) => item.isBonus).toList();
      for (int itemIndex = 0; itemIndex < nonBonusItems.length; itemIndex++) {
        final item = nonBonusItems[itemIndex];
        for (int col = 0; col <= 5; col++) {
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
          switch (col) {
            case 0: cell.value = itemIndex + 1; break;
            case 1: cell.value = item.productName; break;
            case 2: cell.value = item.price; break;
            case 3: cell.value = item.price; break;
            case 4: cell.value = item.quantity; break;
            case 5: cell.value = item.totalPrice; break;
          }
          cell.cellStyle = cellStyle;
        }
        currentRow++;
      }
      for (int itemIndex = 0; itemIndex < bonusItems.length; itemIndex++) {
        final item = bonusItems[itemIndex];
        for (int col = 0; col <= 5; col++) {
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
          switch (col) {
            case 0: cell.value = nonBonusItems.length + itemIndex + 1; break;
            case 1: cell.value = 'Бонус ${item.productName}'; break;
            case 2: cell.value = item.price; break;
            case 3: cell.value = item.price; break;
            case 4: cell.value = item.quantity; break;
            case 5: cell.value = item.totalPrice; break;
          }
          cell.cellStyle = cellStyle;
        }
        currentRow++;
      }
      // Итоги
      final totalQuantity = invoice.items.fold<int>(0, (sum, item) => sum + item.quantity);
      var cellItogo = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      cellItogo.value = 'Итого';
      cellItogo.cellStyle = cellStyle;
      var cellQty = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow));
      cellQty.value = totalQuantity;
      cellQty.cellStyle = cellStyle;
      var cellSum = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cellSum.value = invoice.totalAmount;
      cellSum.cellStyle = cellStyle;
      currentRow++;
      // Адрес доставки
      var cellAddr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      cellAddr.value = 'адрес доставки: ${invoice.outletName}, ${invoice.outletAddress}';
      cellAddr.cellStyle = cellStyle;
      var cellDebt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cellDebt.value = 'долг';
      cellDebt.cellStyle = cellStyle;
      var cellDebtSum = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cellDebtSum.value = invoice.totalAmount;
      cellDebtSum.cellStyle = cellStyle;
      currentRow++;
      // Контактная информация
      var cellContact = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      cellContact.value = '${invoice.salesRepName}';
      cellContact.cellStyle = cellStyle;
      currentRow++;
      // Пустая строка между накладными
      if (invoiceIndex < _filteredInvoices.length - 1) {
        currentRow++;
      }
    }
    // Сохраняем файл
    final bytes = excel.save();
    if (bytes != null) {
      await FileSaver.instance.saveFile(
        name: 'delivery_invoices',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.other,
        customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Накладные на доставке'),
        actions: [
          IconButton(
            icon: Icon(Icons.table_chart),
            tooltip: 'Экспорт в Excel',
            onPressed: _exportInvoicesToExcel,
          ),
          if (!kIsWeb)
            IconButton(
              icon: Icon(Icons.filter_list),
              tooltip: 'Фильтры',
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => _FilterDialog(
                    salesReps: _salesReps,
                    selectedSalesRepId: _selectedSalesRepId,
                    onSalesRepChanged: (val) => setState(() => _selectedSalesRepId = val),
                    selectedPaymentStatus: _selectedPaymentStatus,
                    onPaymentStatusChanged: (val) => setState(() => _selectedPaymentStatus = val),
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    onDateFromChanged: (val) => setState(() => _dateFrom = val),
                    onDateToChanged: (val) => setState(() => _dateTo = val),
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
                      ? Center(child: Text('Нет накладных на доставке'))
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
                            final bgColor = index % 2 == 0 ? Colors.white : Colors.grey.shade100;
                            return Container(
                              color: bgColor,
                              child: ListTile(
                                leading: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                title: Text('Накладная $customNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Точка: ${invoice.outletName}'),
                                    if (invoice.outletAddress != null && invoice.outletAddress.isNotEmpty)
                                      Text('Адрес: ${invoice.outletAddress}'),
                                    Text('Торговый: ${invoice.salesRepName}'),
                                  ],
                                ),
                                trailing: !widget.forSales
                                    ? ElevatedButton(
                                        child: Text('Доставлен'),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('Подтвердите действие'),
                                              content: Text('Вы уверены, что хотите отметить накладную $customNumber как доставленную?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text('Отмена'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: Text('Доставлен'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.delivered);
                                            _loadData();
                                          }
                                        },
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceScreen(invoiceId: invoice.id),
                                    ),
                                  );
                                },
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

// Вспомогательный диалог фильтров
class _FilterDialog extends StatelessWidget {
  final List<SalesRep> salesReps;
  final String? selectedSalesRepId;
  final ValueChanged<String?> onSalesRepChanged;
  final String? selectedPaymentStatus;
  final ValueChanged<String?> onPaymentStatusChanged;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;
  const _FilterDialog({
    required this.salesReps,
    required this.selectedSalesRepId,
    required this.onSalesRepChanged,
    required this.selectedPaymentStatus,
    required this.onPaymentStatusChanged,
    required this.dateFrom,
    required this.dateTo,
    required this.onDateFromChanged,
    required this.onDateToChanged,
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
            DropdownButton<String>(
              value: selectedSalesRepId,
              hint: Text('Торговый'),
              items: [
                DropdownMenuItem(value: 'all', child: Text('Все')),
                ...salesReps.map((rep) => DropdownMenuItem(value: rep.id, child: Text(rep.name)))
              ],
              onChanged: onSalesRepChanged,
            ),
            DropdownButton<String>(
              value: selectedPaymentStatus,
              hint: Text('Оплата'),
              items: [
                DropdownMenuItem(value: 'all', child: Text('Все')),
                DropdownMenuItem(value: 'paid', child: Text('Оплачен')),
                DropdownMenuItem(value: 'not_paid', child: Text('Не оплачен')),
                DropdownMenuItem(value: 'debt', child: Text('Долг')),
              ],
              onChanged: onPaymentStatusChanged,
            ),
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