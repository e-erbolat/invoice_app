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
import 'dart:html' as html;

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
    
    int currentRow = 0;
    
    for (int invoiceIndex = 0; invoiceIndex < selected.length; invoiceIndex++) {
      final invoice = selected[invoiceIndex];
      
      // Заголовок накладной (строка 1)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = 'MELLO AQTOBE';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = DateFormat('dd.MM.yyyy').format(invoice.date.toDate());
      currentRow++;
      
      // Заголовки таблицы (строка 2)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = '№';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = 'Наименование товара';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = 'Цена по прайсу';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = 'Цена со скидкой';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = 'Количество';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = 'Итого';
      currentRow++;
      
      // Товары
      for (int itemIndex = 0; itemIndex < invoice.items.length; itemIndex++) {
        final item = invoice.items[itemIndex];
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = itemIndex + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = item.productName;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = item.price;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = item.price;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = item.quantity;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = item.totalPrice;
        currentRow++;
      }
      
      // Итоги
      final totalQuantity = invoice.items.fold<int>(0, (sum, item) => sum + item.quantity);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = 'Итого';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = totalQuantity;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = invoice.totalAmount;
      currentRow++;
      
      // Адрес доставки
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = 'адрес доставки: ${invoice.outletAddress}';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = 'долг';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow)).value = invoice.totalAmount;
      currentRow++;
      
      // Контактная информация
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = '${invoice.salesRepName}';
      currentRow++;
      
      // Пустая строка между накладными
      if (invoiceIndex < selected.length - 1) {
        currentRow++;
      }
    }
    
    // Сохраняем файл
    final bytes = excel.save();
    if (bytes != null) {
      if (kIsWeb) {
        // Для веб-версии используем download
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'packing_invoices.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Для мобильных платформ можно использовать другие методы
        print('Excel файл создан, но скачивание не поддерживается на этой платформе');
      }
    }
    _clearSelection();
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Удаляю фильтры по торговому и оплате, оставляю только даты
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
                      ? Center(child: Text('Нет накладных на сборке'))
                      : Column(
                          children: [
                            if (_selectionMode)
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.picture_as_pdf),
                                    label: Text('PDF'),
                                    onPressed: _exportSelectedInvoices,
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.table_chart),
                                    label: Text('Excel'),
                                    onPressed: _exportSelectedInvoicesToExcel,
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.done_all),
                                    label: Text('Принять все'),
                                    onPressed: _acceptAllSelected,
                                  ),
                                  TextButton(
                                    onPressed: _clearSelection,
                                    child: Text('Отмена'),
                                  ),
                                ],
                              ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _filteredInvoices.length,
                                itemBuilder: (context, index) {
                                  final invoice = _filteredInvoices[index];
                                  final checked = _selectedInvoiceIds.contains(invoice.id);
                                  return GestureDetector(
                                    onLongPress: () => _toggleInvoiceSelection(invoice.id),
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (_selectionMode)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 8, top: 4),
                                                child: Checkbox(
                                                  value: checked,
                                                  onChanged: (_) => _toggleInvoiceSelection(invoice.id),
                                                ),
                                              ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Накладная №${invoice.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  Text('Точка: ${invoice.outletName}'),
                                                  if (invoice.outletAddress.isNotEmpty)
                                                    Text('Адрес: ${invoice.outletAddress}'),
                                                  const SizedBox(height: 12),
                                                  if (!widget.forSales)
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        ElevatedButton(
                                                          child: Text('Передать на доставку'),
                                                          onPressed: () => _showConfirmDialog(invoice),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        OutlinedButton(
                                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                                          onPressed: () => _showDeleteDialog(invoice),
                                                          child: Text('Отклонить'),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
} 