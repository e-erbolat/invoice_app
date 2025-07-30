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
import '../services/excel_export_service.dart';
import 'package:file_saver/file_saver.dart' as fs;
import 'package:mime/mime.dart';
// import 'dart:html' as html; // УДАЛЕНО
import '../screens/invoice_create_screen.dart'; // Added import for InvoiceCreateScreen

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

    // ЛОГИРОВАНИЕ
    print('[DEBUG] Загружено накладных: ${invoices.length}');
    for (final inv in invoices) {
      print('[DEBUG] Invoice id=${inv.id}, status=${inv.status} (type: ${inv.status.runtimeType}), outlet=${inv.outletName}');
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
    
    // Сортируем по дате принятия оплаты (для архива) или по дате создания
    filtered.sort((a, b) {
      // Если накладная в архиве и есть дата принятия, сортируем по ней
      if (a.status == InvoiceStatus.archive && a.acceptedAt != null &&
          b.status == InvoiceStatus.archive && b.acceptedAt != null) {
        return b.acceptedAt!.compareTo(a.acceptedAt!); // Новые сначала
      }
      // Иначе сортируем по дате создания
      return b.date.compareTo(a.date);
    });

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



  bool _isExporting = false;

  void _exportInvoicesToExcel() async {
    if (_isExporting) return; // Защита от множественных нажатий
    
    setState(() {
      _isExporting = true;
    });
    
    try {
      await ExcelExportService.exportInvoicesToExcel(
        invoices: _filteredInvoices,
        sheetName: 'Архив накладных',
        fileName: 'archive_invoices',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case InvoiceStatus.review:
        return Colors.orange;
      case InvoiceStatus.packing:
        return Colors.blue;
      case InvoiceStatus.delivery:
        return Colors.purple;
      case InvoiceStatus.delivered:
        return Colors.green;
      case InvoiceStatus.cancelled:
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
          if (!kIsWeb)
            IconButton(
              icon: Icon(Icons.filter_list),
              tooltip: 'Фильтры',
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => _FilterDialog(
                    searchQuery: _searchQuery,
                    onSearchChanged: (val) => setState(() => _searchQuery = val),
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (val) => setState(() => _selectedFilter = val ?? 'all'),
                    salesReps: _salesReps,
                    selectedSalesRepId: _selectedSalesRepId,
                    onSalesRepChanged: (val) => setState(() => _selectedSalesRepId = val),
                    selectedPaymentStatus: _selectedPaymentStatus,
                    onPaymentStatusChanged: (val) => setState(() => _selectedPaymentStatus = val),
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    onDateFromChanged: (val) => setState(() => _dateFrom = val),
                    onDateToChanged: (val) => setState(() => _dateTo = val),
                    onApply: () {
                      _filterInvoices();
                      Navigator.pop(context);
                    },
                  ),
                );
                _filterInvoices();
              },
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
        ],
      ),
      body: Column(
        children: [
          if (kIsWeb)
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
                          final date = invoice.date.toDate();
                          final dateStr = DateFormat('dd.MM.yyyy').format(date);
                          final dateNum = DateFormat('ddMMyyyy').format(date);
                          
                          // Для архива показываем дату принятия оплаты, если есть
                          String displayDateStr = dateStr;
                          if (invoice.status == InvoiceStatus.archive && invoice.acceptedAt != null) {
                            final acceptedDate = invoice.acceptedAt!.toDate();
                            displayDateStr = DateFormat('dd.MM.yyyy').format(acceptedDate);
                          }
                          String suffix = '';
                          final idMatch = RegExp(r'(\d{4})$').firstMatch(invoice.id);
                          if (idMatch != null) {
                            suffix = idMatch.group(1)!;
                          } else {
                            suffix = (index + 1).toString().padLeft(4, '0');
                          }
                          final customNumber = '$dateNum-$suffix';
                          final bgColor = index % 2 == 0 ? Colors.white : Colors.grey.shade100;
                          final isSelected = _selectedInvoiceIds.contains(invoice.id);
                          return Container(
                            color: bgColor,
                            child: ListTile(
                              leading: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(displayDateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              title: Text(
                                'Накладная $customNumber',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${invoice.outletName} • ${invoice.salesRepName}'),
                                  Text('Адрес: ${invoice.outletAddress}'),
                                  Text(
                                    '${displayDateStr} • ${invoice.items.length} товаров',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Итого: ${invoice.totalAmount.toStringAsFixed(2)} ₸',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(invoice.status),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      InvoiceStatus.getName(invoice.status),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Кнопка деталей
                                  IconButton(
                                    icon: const Icon(Icons.info_outline),
                                    onPressed: () => _showInvoiceDetails(invoice),
                                    tooltip: 'Детали накладной',
                                  ),
                                  // Чекбокс для выбора
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) => _toggleInvoiceSelection(invoice.id),
                                  ),
                                ],
                              ),
                              onTap: () => _showInvoiceDetails(invoice),
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
              Text('Дата создания: ${DateFormat('dd.MM.yyyy').format(invoice.date.toDate())}'),
              if (invoice.status == InvoiceStatus.archive && invoice.acceptedAt != null)
                Text('Дата принятия: ${DateFormat('dd.MM.yyyy').format(invoice.acceptedAt!.toDate())}'),
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
                      InvoiceStatus.getName(invoice.status),
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
              // Итоговая сумма
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Итоговая сумма:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${invoice.totalAmount.toStringAsFixed(2)} ₸',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              // Информация о платежах
              if (invoice.isPaid && (invoice.bankAmount != null || invoice.cashAmount != null)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Детали оплаты:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (invoice.bankAmount != null && invoice.bankAmount! > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Банк:'),
                            Text('${invoice.bankAmount!.toStringAsFixed(2)} ₸'),
                          ],
                        ),
                      if (invoice.cashAmount != null && invoice.cashAmount! > 0) ...[
                        if (invoice.bankAmount != null && invoice.bankAmount! > 0)
                          const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Наличные:'),
                            Text('${invoice.cashAmount!.toStringAsFixed(2)} ₸'),
                          ],
                        ),
                      ],
                    ],
                  ),
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/invoice',
                arguments: invoice,
              );
            },
            child: const Text('Полные детали'),
          ),
        ],
      ),
    );
  }
} 

// Вспомогательный диалог фильтров
class _FilterDialog extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final List<SalesRep> salesReps;
  final String? selectedSalesRepId;
  final ValueChanged<String?> onSalesRepChanged;
  final String? selectedPaymentStatus;
  final ValueChanged<String?> onPaymentStatusChanged;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final VoidCallback onApply;
  const _FilterDialog({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.salesReps,
    required this.selectedSalesRepId,
    required this.onSalesRepChanged,
    required this.selectedPaymentStatus,
    required this.onPaymentStatusChanged,
    required this.dateFrom,
    required this.dateTo,
    required this.onDateFromChanged,
    required this.onDateToChanged,
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
            TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по точке, торговому или ID накладной',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: searchQuery),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Период: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedFilter,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Все')),
                      DropdownMenuItem(value: 'today', child: Text('Сегодня')),
                      DropdownMenuItem(value: 'week', child: Text('Неделя')),
                      DropdownMenuItem(value: 'month', child: Text('Месяц')),
                    ],
                    onChanged: onFilterChanged,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedSalesRepId ?? 'all',
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Все торговые')),
                      ...salesReps.map((rep) => DropdownMenuItem(value: rep.id, child: Text(rep.name))),
                    ],
                    onChanged: onSalesRepChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedPaymentStatus ?? 'all',
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Все оплаты')),
                      DropdownMenuItem(value: 'paid', child: Text('Оплачено')),
                      DropdownMenuItem(value: 'not_paid', child: Text('Не оплачено')),
                      DropdownMenuItem(value: 'debt', child: Text('Долг')),
                    ],
                    onChanged: onPaymentStatusChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dateFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) onDateFromChanged(picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата с',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      child: Text(dateFrom != null ? DateFormat('dd.MM.yyyy').format(dateFrom!) : 'Не выбрано'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dateTo ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) onDateToChanged(picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата по',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      child: Text(dateTo != null ? DateFormat('dd.MM.yyyy').format(dateTo!) : 'Не выбрано'),
                    ),
                  ),
                ),
              ],
            ),
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