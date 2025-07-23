import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../models/sales_rep.dart';
import '../services/firebase_service.dart';
import 'invoice_screen.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/outlet.dart';
import '../services/auth_service.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_saver/file_saver.dart' as fs;

class AdminPackingInvoicesScreen extends StatefulWidget {
  final bool forSales;
  const AdminPackingInvoicesScreen({Key? key, this.forSales = false}) : super(key: key);
  @override
  _AdminPackingInvoicesScreenState createState() => _AdminPackingInvoicesScreenState();
}

class _AdminPackingInvoicesScreenState extends State<AdminPackingInvoicesScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final FirebaseService _firebaseService = FirebaseService();
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  List<SalesRep> _salesReps = [];
  List<Outlet> _outlets = [];
  bool _isLoading = true;
  String? _selectedSalesRepId;
  String? _selectedPaymentStatus; // 'all', 'paid', 'not_paid', 'debt'
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _errorMessage;
  Set<String> _selectedInvoiceIds = {};
  bool _selectionMode = false;
  
  // Шрифты для PDF
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  @override
  void initState() {
    super.initState();
    _loadFonts();
    _loadData();
  }

  Future<void> _loadFonts() async {
    try {
      // Используем встроенные шрифты с поддержкой кириллицы
      _regularFont = pw.Font.helvetica();
      _boldFont = pw.Font.helveticaBold();
    } catch (e) {
      print('Ошибка загрузки шрифтов: $e');
      // Используем стандартные шрифты как fallback
    }
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      List<Invoice> invoices;
      if (widget.forSales) {
        final user = await AuthService().getCurrentUser();
        if (user == null) throw Exception('Пользователь не найден');
        print('[AdminPackingInvoicesScreen] Текущий пользователь: uid=${user.uid}, role=${user.role}, salesRepId=${user.salesRepId}');
        if (user.salesRepId == null) throw Exception('У пользователя не заполнен salesRepId!');
        invoices = await _invoiceService.getInvoicesByStatusAndSalesRepSimple(InvoiceStatus.packing, user.salesRepId!);
      } else {
        invoices = await _invoiceService.getInvoicesByStatus(InvoiceStatus.packing);
      }
      final salesReps = await _firebaseService.getSalesReps();
      final outlets = await _firebaseService.getOutlets();
      setState(() {
        _invoices = invoices;
        _filteredInvoices = invoices;
        _salesReps = salesReps;
        _outlets = outlets;
        _isLoading = false;
      });
      
      // Добавляем отладочную информацию
      print('[AdminPackingInvoicesScreen] Загружено накладных: ${invoices.length}');
      for (var invoice in invoices) {
        print('[AdminPackingInvoicesScreen] Накладная ${invoice.id}: статус = ${invoice.status}');
      }
      
      debugPrint('[AdminPackingInvoicesScreen] Загружено накладных: "${invoices.length.toString()}"');
    } catch (e, st) {
      debugPrint('[AdminPackingInvoicesScreen] Ошибка: $e\n$st');
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
          title: Text('Передать на доставку?'),
          content: Text('Вы уверены, что хотите передать накладную №${invoice.id} на доставку?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.delivery);
                _loadData();
              },
              child: Text('Передать'),
            ),
          ],
        ),
      );
    }
  }

  void _showDeleteDialog(Invoice invoice) {
    if (!widget.forSales) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Отклонить накладную?'),
          content: Text('Вы уверены, что хотите отклонить и удалить накладную №${invoice.id}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _invoiceService.deleteInvoice(invoice.id);
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Отклонить'),
            ),
          ],
        ),
      );
    }
  }

  void _toggleInvoiceSelection(String invoiceId) {
    setState(() {
      if (_selectedInvoiceIds.contains(invoiceId)) {
        _selectedInvoiceIds.remove(invoiceId);
      } else {
        _selectedInvoiceIds.add(invoiceId);
      }
      _selectionMode = _selectedInvoiceIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedInvoiceIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _exportSelectedInvoices() async {
    final selected = _filteredInvoices.where((inv) => _selectedInvoiceIds.contains(inv.id)).toList();
    if (selected.isEmpty) return;
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('Накладные на сборке', 
                style: pw.TextStyle(fontSize: 24, font: _boldFont))),
              pw.SizedBox(height: 20),
              ...selected.map((inv) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Накладная #${inv.id}', 
                        style: pw.TextStyle(fontSize: 18, font: _boldFont)),
                      pw.Text('Точка: ${inv.outletName}', 
                        style: pw.TextStyle(font: _regularFont)),
                      if (inv.outletAddress.isNotEmpty) 
                        pw.Text('Адрес: ${inv.outletAddress}', 
                          style: pw.TextStyle(font: _regularFont)),
                      pw.Text('Дата: ${DateFormat('dd.MM.yyyy').format(inv.date.toDate())}', 
                        style: pw.TextStyle(font: _regularFont)),
                      pw.SizedBox(height: 8),
                      pw.Text('Товары:', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: _boldFont)),
                      ...inv.items.map((item) => pw.Text(
                        '${item.productName} - ${item.quantity} × ${item.price.toStringAsFixed(2)} ₸ = ${item.totalPrice.toStringAsFixed(2)} ₸',
                        style: pw.TextStyle(font: _regularFont)
                      )),
                      pw.SizedBox(height: 8),
                      pw.Text('Сумма: ${inv.totalAmount.toStringAsFixed(2)} ₸', 
                        style: pw.TextStyle(font: _regularFont)),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'packing_invoices.pdf');
    }
    _clearSelection();
  }

  Future<void> _acceptAllSelected() async {
    final selected = _filteredInvoices.where((inv) => _selectedInvoiceIds.contains(inv.id)).toList();
    if (selected.isEmpty) return;
    for (final inv in selected) {
      await _invoiceService.updateInvoiceStatus(inv.id, InvoiceStatus.delivery);
    }
    _loadData();
    _clearSelection();
  }

  void _exportSelectedInvoicesToExcel() async {
    final selected = _filteredInvoices.where((inv) => _selectedInvoiceIds.contains(inv.id)).toList();
    if (selected.isEmpty) return;
    
    // Создаем Excel документ
    final excel = Excel.createExcel();
    final sheet = excel['Накладные на сборке'];
    final cellStyle = CellStyle(
      fontFamily: 'Times New Roman',
      fontSize: 25,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    int currentRow = 0;
    
    for (int invoiceIndex = 0; invoiceIndex < selected.length; invoiceIndex++) {
      final invoice = selected[invoiceIndex];
      
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
      if (invoiceIndex < selected.length - 1) {
        currentRow++;
      }
    }
    
    
    // Сохраняем файл
    final bytes = excel.save();
    if (bytes != null) {
      await FileSaver.instance.saveFile(
        name: 'packing_invoices',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.other,
        customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
    // _clearSelection(); // если нет такой функции, убрать
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Накладные на сборке'), actions: [
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
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
                          Text('Выбрано:  ${_selectedInvoiceIds.length} из ${_filteredInvoices.length}', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => _selectDate(context, true),
                            child: Text(_dateFrom == null ? 'С даты' : DateFormat('dd.MM.yyyy').format(_dateFrom!)),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: () => _selectDate(context, false),
                            child: Text(_dateTo == null ? 'По дату' : DateFormat('dd.MM.yyyy').format(_dateTo!)),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: () {
                              final now = DateTime.now();
                              final today = DateTime(now.year, now.month, now.day);
                              setState(() {
                                _dateFrom = today;
                                _dateTo = today;
                              });
                              _filterInvoices();
                            },
                            child: Text('Сегодня'),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: () {
                              final now = DateTime.now().add(Duration(days: 1));
                              final tomorrow = DateTime(now.year, now.month, now.day);
                              setState(() {
                                _dateFrom = tomorrow;
                                _dateTo = tomorrow;
                              });
                              _filterInvoices();
                            },
                            child: Text('Завтра'),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: _clearFilters,
                            child: Text('Сбросить фильтры'),
                          ),
                          const Spacer(),
                          Builder(
                            builder: (context) {
                              final selected = _filteredInvoices.where((inv) => _selectedInvoiceIds.contains(inv.id)).toList();
                              final total = selected.fold<double>(0.0, (sum, inv) => sum + inv.totalAmount);
                              return Text(
                                'Общая сумма: ${total.toStringAsFixed(2)} ₸',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                  fontSize: 16,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (_selectedInvoiceIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.table_chart),
                              label: Text('Экспорт в Excel'),
                              onPressed: _exportSelectedInvoicesToExcel,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: Icon(Icons.picture_as_pdf),
                              label: Text('Экспорт в PDF'),
                              onPressed: _exportSelectedInvoices,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredInvoices.isEmpty
                      ? Center(child: Text('Нет накладных на сборке'))
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
                              title: Text('Накладная $customNumber'),
                              subtitle: Text('Точка: ${invoice.outletName}\nАдрес: ${invoice.outletAddress}\nТорговый: ${invoice.salesRepName}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${invoice.totalAmount.toStringAsFixed(2)} ₸',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (_selectionMode)
                                    Checkbox(
                                      value: _selectedInvoiceIds.contains(invoice.id),
                                      onChanged: (value) => _toggleInvoiceSelection(invoice.id),
                                    ),
                                ],
                              ),
                              onTap: _selectionMode
                                  ? () => _toggleInvoiceSelection(invoice.id)
                                  : () {
                                      // Открыть детали накладной
                                    },
                              onLongPress: () {
                                if (!_selectionMode) {
                                  setState(() {
                                    _selectionMode = true;
                                    _selectedInvoiceIds.add(invoice.id);
                                  });
                                }
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