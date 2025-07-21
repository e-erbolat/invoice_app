import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sales_rep.dart'; // Added import for SalesRep
import '../services/firebase_service.dart'; // Added import for FirebaseService
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  _InvoiceListScreenState createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, today, week, month
  final Set<String> _selectedInvoiceIds = {};
  List<SalesRep> _salesReps = [];
  String? _selectedSalesRepId;
  String? _selectedPaymentStatus; // 'all', 'paid', 'not_paid', 'debt'
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final FirebaseService _firebaseService = FirebaseService();
  
  // Шрифты для PDF
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  @override
  void initState() {
    super.initState();
    _loadFonts();
    _loadUserAndInvoices();
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

  Future<void> _loadUserAndInvoices() async {
    setState(() {
      _isLoading = true;
    });
    final user = await _authService.getCurrentUser();
    List<Invoice> invoices;
    final salesReps = await _firebaseService.getSalesReps();
    if (user != null && user.role == 'sales') {
      invoices = await _invoiceService.getInvoicesBySalesRep(user.uid);
    } else {
      invoices = await _invoiceService.getAllInvoices();
    }
    if (mounted) {
      setState(() {
        _currentUser = user;
        _invoices = invoices;
        _filteredInvoices = invoices;
        _salesReps = salesReps;
        _isLoading = false;
      });
    }
  }

  void _filterInvoices() {
    List<Invoice> filtered = _invoices;

    // Применяем поиск
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final query = _searchQuery.toLowerCase();
        return invoice.outletName.toLowerCase().contains(query) ||
               invoice.salesRepName.toLowerCase().contains(query) ||
               invoice.id.toLowerCase().contains(query);
      }).toList();
    }

    // Применяем фильтр по торговому
    if (_selectedSalesRepId != null && _selectedSalesRepId != 'all') {
      filtered = filtered.where((inv) => inv.salesRepId == _selectedSalesRepId).toList();
    }
    // Применяем фильтр по оплате
    if (_selectedPaymentStatus != null && _selectedPaymentStatus != 'all') {
      if (_selectedPaymentStatus == 'paid') {
        filtered = filtered.where((inv) => inv.isPaid).toList();
      } else if (_selectedPaymentStatus == 'not_paid') {
        filtered = filtered.where((inv) => !inv.isPaid && !inv.isDebt).toList();
      } else if (_selectedPaymentStatus == 'debt') {
        filtered = filtered.where((inv) => inv.isDebt).toList();
      }
    }
    // Применяем фильтр по дате
    if (_dateFrom != null) {
      filtered = filtered.where((inv) => inv.date.toDate().isAfter(_dateFrom!) || inv.date.toDate().isAtSameMomentAs(_dateFrom!)).toList();
    }
    if (_dateTo != null) {
      filtered = filtered.where((inv) => inv.date.toDate().isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
    }

    // Применяем фильтр по периоду (старый)
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'today':
        filtered = filtered.where((invoice) {
          final invoiceDate = invoice.date.toDate();
          return invoiceDate.year == now.year &&
                 invoiceDate.month == now.month &&
                 invoiceDate.day == now.day;
        }).toList();
        break;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered.where((invoice) {
          return invoice.date.toDate().isAfter(weekAgo);
        }).toList();
        break;
      case 'month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        filtered = filtered.where((invoice) {
          return invoice.date.toDate().isAfter(monthAgo);
        }).toList();
        break;
    }

    setState(() {
      _filteredInvoices = filtered;
    });
  }

  void _toggleInvoiceSelection(String invoiceId) {
    setState(() {
      if (_selectedInvoiceIds.contains(invoiceId)) {
        _selectedInvoiceIds.remove(invoiceId);
      } else {
        _selectedInvoiceIds.add(invoiceId);
      }
    });
  }

  void _printSelectedInvoices() async {
    if (_selectedInvoiceIds.isEmpty) return;
    
    final selectedInvoices = _invoices.where((invoice) => _selectedInvoiceIds.contains(invoice.id)).toList();
    
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Накладные', 
                  style: pw.TextStyle(
                    fontSize: 24, 
                    font: _boldFont,
                  )
                ),
              ),
              pw.SizedBox(height: 20),
              ...selectedInvoices.map((invoice) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Накладная #${invoice.id.substring(invoice.id.length - 6)}', 
                           style: pw.TextStyle(fontSize: 18, font: _boldFont)),
                    pw.Text('Дата: ${DateFormat('dd.MM.yyyy').format(invoice.date.toDate())}', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.Text('Торговая точка: ${invoice.outletName}', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.Text('Торговый представитель: ${invoice.salesRepName}', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.Text('Статус: ${invoice.status}', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.Text('Оплата: ${invoice.isPaid ? "Оплачен (${invoice.paymentType})" : invoice.isDebt ? "Долг" : "Не оплачен"}', 
                           style: pw.TextStyle(font: _regularFont)),
                    if (invoice.isPaid) ...[
                      pw.Text('Принятие админом: ${invoice.acceptedByAdmin ? "Принял" : "Не принял"}', 
                             style: pw.TextStyle(font: _regularFont)),
                      pw.Text('Принятие суперадмином: ${invoice.acceptedBySuperAdmin ? "Принял" : "Не принял"}', 
                             style: pw.TextStyle(font: _regularFont)),
                    ],
                    pw.Text('Сумма: ${invoice.totalAmount.toStringAsFixed(2)} ₸', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.SizedBox(height: 10),
                    pw.Text('Товары:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: _boldFont)),
                    ...invoice.items.map((item) => pw.Text(
                      '${item.productName} - ${item.quantity} шт. × ${item.price.toStringAsFixed(2)} ₸ = ${item.totalPrice.toStringAsFixed(2)} ₸',
                      style: pw.TextStyle(font: _regularFont)
                    )),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  void _exportSelectedInvoicesToPdf() async {
    if (_selectedInvoiceIds.isEmpty) return;
    
    final selectedInvoices = _invoices.where((invoice) => _selectedInvoiceIds.contains(invoice.id)).toList();
    
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Накладные', 
                  style: pw.TextStyle(
                    fontSize: 24, 
                    font: _boldFont,
                  )
                ),
              ),
              pw.SizedBox(height: 20),
              ...selectedInvoices.map((invoice) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Накладная #${invoice.id.substring(invoice.id.length - 6)}', 
                           style: pw.TextStyle(fontSize: 18, font: _boldFont)),
                    pw.Text('Дата: ${DateFormat('dd.MM.yyyy').format(invoice.date.toDate())}', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.Text('Торговая точка: ${invoice.outletName}', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.Text('Торговый представитель: ${invoice.salesRepName}', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.Text('Статус: ${invoice.status}', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.Text('Оплата: ${invoice.isPaid ? "Оплачен (${invoice.paymentType})" : invoice.isDebt ? "Долг" : "Не оплачен"}', 
                           style: pw.TextStyle(font: _regularFont)),
                    if (invoice.isPaid) ...[
                      pw.Text('Принятие админом: ${invoice.acceptedByAdmin ? "Принял" : "Не принял"}', 
                             style: pw.TextStyle(font: _regularFont)),
                      pw.Text('Принятие суперадмином: ${invoice.acceptedBySuperAdmin ? "Принял" : "Не принял"}', 
                             style: pw.TextStyle(font: _regularFont)),
                    ],
                    pw.Text('Сумма: ${invoice.totalAmount.toStringAsFixed(2)} ₸', 
                           style: pw.TextStyle(font: _regularFont)),
                    pw.SizedBox(height: 10),
                    pw.Text('Товары:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: _boldFont)),
                    ...invoice.items.map((item) => pw.Text(
                      '${item.productName} - ${item.quantity} шт. × ${item.price.toStringAsFixed(2)} ₸ = ${item.totalPrice.toStringAsFixed(2)} ₸',
                      style: pw.TextStyle(font: _regularFont)
                    )),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
    
    await Printing.sharePdf(bytes: await doc.save(), filename: 'invoices.pdf');
  }

  void _exportSelectedInvoicesToExcel() async {
    if (_selectedInvoiceIds.isEmpty) return;
    
    final selectedInvoices = _invoices.where((invoice) => _selectedInvoiceIds.contains(invoice.id)).toList();
    
    // Создаем Excel документ
    final excel = Excel.createExcel();
    final sheet = excel['Накладные'];
    
    int currentRow = 0;
    
    for (int invoiceIndex = 0; invoiceIndex < selectedInvoices.length; invoiceIndex++) {
      final invoice = selectedInvoices[invoiceIndex];
      
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
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = 'конс';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = 'долг';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow)).value = invoice.totalAmount;
      currentRow++;
      
      // Контактная информация
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = '${invoice.salesRepName}';
      currentRow++;
      
      // Пустая строка между накладными
      if (invoiceIndex < selectedInvoices.length - 1) {
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
          ..setAttribute('download', 'invoices.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Для мобильных платформ можно использовать другие методы
        print('Excel файл создан, но скачивание не поддерживается на этой платформе');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'передан':
        return Colors.blue;
      case 'доставлен':
        return Colors.green;
      case 'отменен':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Архив накладных'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserAndInvoices,
          ),
          if (_selectedInvoiceIds.isNotEmpty && kIsWeb)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Распечатать выбранные',
              onPressed: _printSelectedInvoices,
            ),
          if (_selectedInvoiceIds.isNotEmpty && !kIsWeb)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Экспорт в PDF',
              onPressed: _exportSelectedInvoicesToPdf,
            ),
          if (_selectedInvoiceIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.table_chart),
              tooltip: 'Экспорт в Excel',
              onPressed: _exportSelectedInvoicesToExcel,
            ),
        ],
      ),
      body: Column(
        children: [
          // Поиск и фильтры
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Поиск
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Поиск по точке, торговому или ID накладной',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _filterInvoices();
                  },
                ),
                const SizedBox(height: 12),
                // Фильтры по дате
                Row(
                  children: [
                    const Text('Период: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Все')),
                          DropdownMenuItem(value: 'today', child: Text('Сегодня')),
                          DropdownMenuItem(value: 'week', child: Text('Неделя')),
                          DropdownMenuItem(value: 'month', child: Text('Месяц')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                          _filterInvoices();
                        },
                      ),
                    ),
                  ],
                ),
                // Фильтры по торговому, оплате, дате
                Row(
                  children: [
                    // Торговый
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedSalesRepId ?? 'all',
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('Все торговые')),
                          ..._salesReps.map((rep) => DropdownMenuItem(value: rep.id, child: Text(rep.name))),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSalesRepId = value;
                          });
                          _filterInvoices();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Оплата
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedPaymentStatus ?? 'all',
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Все оплаты')),
                          DropdownMenuItem(value: 'paid', child: Text('Оплачено')),
                          DropdownMenuItem(value: 'not_paid', child: Text('Не оплачено')),
                          DropdownMenuItem(value: 'debt', child: Text('Долг')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentStatus = value;
                          });
                          _filterInvoices();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Дата
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _dateFrom = picked;
                            });
                            _filterInvoices();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Дата с',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.date_range),
                          ),
                          child: Text(_dateFrom != null ? DateFormat('dd.MM.yyyy').format(_dateFrom!) : 'Не выбрано'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _dateTo = picked;
                            });
                            _filterInvoices();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Дата по',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.date_range),
                          ),
                          child: Text(_dateTo != null ? DateFormat('dd.MM.yyyy').format(_dateTo!) : 'Не выбрано'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Список накладных
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Накладные не найдены',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _filteredInvoices[index];
                          final isSelected = _selectedInvoiceIds.contains(invoice.id);
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: Checkbox(
                                value: isSelected,
                                onChanged: (value) => _toggleInvoiceSelection(invoice.id),
                              ),
                              title: Text(
                                'Накладная #${invoice.id.substring(invoice.id.length - 6)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${invoice.outletName} • ${invoice.salesRepName}'),
                                  Text(
                                    '${DateFormat('dd.MM.yyyy').format(invoice.date.toDate())} • ${invoice.items.length} товаров',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  // Статус накладной
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(invoice.status),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      invoice.status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // Статус оплаты
                                  Row(
                                    children: [
                                      Icon(
                                        invoice.isPaid ? Icons.payment : Icons.payment_outlined,
                                        size: 14,
                                        color: invoice.isPaid ? Colors.green : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        invoice.isPaid 
                                          ? 'Оплачен (${invoice.paymentType})'
                                          : invoice.isDebt 
                                            ? 'Долг'
                                            : 'Не оплачен',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: invoice.isPaid ? Colors.green : Colors.orange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Принятие денег
                                  if (invoice.isPaid) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          invoice.acceptedByAdmin ? Icons.check_circle : Icons.pending,
                                          size: 12,
                                          color: invoice.acceptedByAdmin ? Colors.green : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Админ: ${invoice.acceptedByAdmin ? "Принял" : "Не принял"}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: invoice.acceptedByAdmin ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          invoice.acceptedBySuperAdmin ? Icons.check_circle : Icons.pending,
                                          size: 12,
                                          color: invoice.acceptedBySuperAdmin ? Colors.green : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Суперадмин: ${invoice.acceptedBySuperAdmin ? "Принял" : "Не принял"}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: invoice.acceptedBySuperAdmin ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${invoice.totalAmount.toStringAsFixed(2)} ₸',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Text(
                                    'Нажмите для деталей',
                                    style: TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              onTap: () {
                                // Показать детали накладной
                                _showInvoiceDetails(invoice);
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

  void _showInvoiceDetails(Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Накладная #${invoice.id.substring(invoice.id.length - 6)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Дата: ${DateFormat('dd.MM.yyyy').format(invoice.date.toDate())}'),
              Text('Торговая точка: ${invoice.outletName}'),
              Text('Торговый представитель: ${invoice.salesRepName}'),
              const SizedBox(height: 16),
              // Статус накладной
              Row(
                children: [
                  const Text('Статус: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(invoice.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      invoice.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Статус оплаты
              Row(
                children: [
                  const Text('Оплата: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Icon(
                    invoice.isPaid ? Icons.payment : Icons.payment_outlined,
                    size: 16,
                    color: invoice.isPaid ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    invoice.isPaid 
                      ? 'Оплачен (${invoice.paymentType})'
                      : invoice.isDebt 
                        ? 'Долг'
                        : 'Не оплачен',
                    style: TextStyle(
                      color: invoice.isPaid ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Принятие денег
              if (invoice.isPaid) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Принятие: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Icon(
                      invoice.acceptedByAdmin ? Icons.check_circle : Icons.pending,
                      size: 16,
                      color: invoice.acceptedByAdmin ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Админ: ${invoice.acceptedByAdmin ? "Принял" : "Не принял"}',
                      style: TextStyle(
                        color: invoice.acceptedByAdmin ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 60), // Отступ для выравнивания
                    Icon(
                      invoice.acceptedBySuperAdmin ? Icons.check_circle : Icons.pending,
                      size: 16,
                      color: invoice.acceptedBySuperAdmin ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Суперадмин: ${invoice.acceptedBySuperAdmin ? "Принял" : "Не принял"}',
                      style: TextStyle(
                        color: invoice.acceptedBySuperAdmin ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text('Товары:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...invoice.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item.productName} - ${item.quantity} шт. × ${item.price.toStringAsFixed(2)} ₸ = ${item.totalPrice.toStringAsFixed(2)} ₸',
                ),
              )),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Итого:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${invoice.totalAmount.toStringAsFixed(2)} ₸',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
} 