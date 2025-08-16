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
import '../services/excel_export_service.dart';
import 'package:file_saver/file_saver.dart' as fs;
import '../services/satushi_api_service.dart';
import '../services/auth_service.dart';

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
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _errorMessage;
  Set<String> _selectedInvoiceIds = {};
  bool _selectionMode = false;
  
  // Шрифты для PDF
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  // Вспомогательные парсеры адреса/телефона
  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp('[^0-9]'), '');
    if (digits.startsWith('8')) return '7${digits.substring(1)}';
    return digits;
  }

  String? _extractApt(String address) {
    final m = RegExp(r'(кв\.?\s*|апт\.?\s*|апартамент\s*)(\d+)').firstMatch(address.toLowerCase());
    return m != null ? m.group(2) : '';
  }

  String? _extractBuilding(String address) {
    final m = RegExp(r'(дом\s*|д\.\s*)(\d+[a-zA-Z]?)').firstMatch(address.toLowerCase());
    return m != null ? m.group(2) : '';
  }

  String _extractDistrict(String address) {
    // Возвращаем часть до запятой как район, если есть
    return address.split(',').first.trim();
  }

  String _extractStreetName(String address) {
    // Простой хелпер: уберём номер дома, вернём название улицы
    final parts = address.split(',').first.split(' ');
    if (parts.length <= 1) return address;
    parts.removeWhere((p) => RegExp(r'^\d').hasMatch(p));
    return parts.join(' ').trim();
  }

  String _extractStreetNumber(String address) {
    final m = RegExp(r'(\d+[a-zA-Z]?)').firstMatch(address);
    return m?.group(1) ?? '';
  }

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
      _dateFrom = null;
      _dateTo = null;
      _filteredInvoices = _invoices;
    });
  }

  Future<void> _sendToSatushi(Invoice invoice) async {
    try {
      final user = await AuthService().getCurrentUser();
      final token = user?.satushiToken;
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('satushiToken не задан в профиле')));
        return;
      }

      // Найдём точку
      final outlet = _outlets.firstWhere(
        (o) => o.id == invoice.outletId || o.name == invoice.outletName,
        orElse: () => Outlet(
          id: invoice.outletId,
          name: invoice.outletName,
          address: invoice.outletAddress,
          phone: '',
          contactPerson: '',
          region: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // map productId -> satushiCode если в item отсутствует
      final allProducts = await _firebaseService.getProducts();
      final Map<String, String?> idToSatushi = { for (final p in allProducts) p.id : p.satushiCode };

      // Проверка наличия satushiCode
      final missing = <String>[];
      for (final it in invoice.items) {
        final code = it.satushiCode ?? idToSatushi[it.productId];
        if ((code == null || code.isEmpty) && !it.isBonus) {
          missing.add(it.productName);
        }
      }
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Нет satushiCode у: ${missing.join(', ')}')),
        );
        return;
      }

      if (outlet.latitude == null || outlet.longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('У точки не указаны координаты (latitude/longitude)')),
        );
        return;
      }

      // Группируем товары по satushiCode, объединяя количество
      final Map<String, Map<String, dynamic>> groupedProducts = {};
      
      for (final item in invoice.items) {
        final code = item.satushiCode ?? idToSatushi[item.productId]!;
        if (groupedProducts.containsKey(code)) {
          // Если товар уже есть, суммируем количество и totalPrice
          groupedProducts[code]!['quantity'] += item.quantity;
          groupedProducts[code]!['totalPrice'] += item.totalPrice;
        } else {
          // Новый товар
          groupedProducts[code] = {
            'code': code,
            'name': item.productName,
            'imageMedium': '',
            'weight': 0.0,
            'deliveryCost': 0.0,
            'quantity': item.quantity,
            'link': '',
            'basePrice': item.price,
            'totalPrice': item.totalPrice,
          };
        }
      }
      
      final products = groupedProducts.values.toList();

      final body = {
        'courierId': '',
        'nonSmsOrder': false,
        'orderType': 'SATU',
        'photoRequired': false,
        'totalPrice': invoice.totalAmount,
        'cityId': '151010000',
        'plannedDeliveryDate': invoice.date.toDate().millisecondsSinceEpoch,
        'deliveryAddress': {
          'apartment': _extractApt(outlet.address),
          'building': _extractBuilding(outlet.address),
          'district': _extractDistrict(outlet.address),
          'formattedAddress': outlet.address.isNotEmpty ? '${outlet.name}, ${outlet.address}' : outlet.name,
          'latitude': outlet.latitude,
          'longitude': outlet.longitude,
          'streetName': _extractStreetName(outlet.address),
          'streetNumber': _extractStreetNumber(outlet.address),
          'town': (outlet.region != null && outlet.region!.isNotEmpty) ? outlet.region : 'Актобе',
        },
        'customer': {
          'cellPhone': _normalizePhone(outlet.phone),
          'firstName': outlet.contactPerson,
          'lastName': '',
          'name': outlet.contactPerson,
        },
        'deliveryMode': 'DELIVERY_LOCAL',
        'products': products,
      };

      final api = SatushiApiService();
      
      // Детальная диагностика
      debugPrint('[Satushi] === DIAGNOSTICS ===');
      debugPrint('[Satushi] outlet: ${outlet.name}');
      debugPrint('[Satushi] outlet.coords: ${outlet.latitude}, ${outlet.longitude}');
      debugPrint('[Satushi] outlet.address: ${outlet.address}');
      debugPrint('[Satushi] outlet.region: ${outlet.region}');
      debugPrint('[Satushi] products count: ${products.length}');
      debugPrint('[Satushi] body: $body');
      debugPrint('[Satushi] ===================');
      
      final resp = await api.createCustomOrder(bearerToken: token, body: body);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заявка в Satushi создана')));
        await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.delivery);
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка Satushi: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
    }
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
                await _sendToSatushi(invoice);
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
          content: Text('Вы уверены, что хотите отклонить накладную №${invoice.id} и вернуть её на рассмотрение?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Возвращаем накладную в статус "на рассмотрении"
                await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.review);
                _loadData();
                
                // Показываем сообщение об успехе
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Накладная возвращена на рассмотрение'),
                    backgroundColor: Colors.orange,
                  ),
                );
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

  Future<void> _transferAllSelected() async {
    final selected = _filteredInvoices.where((inv) => _selectedInvoiceIds.contains(inv.id)).toList();
    if (selected.isEmpty) return;
    
    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Подтвердите действие'),
        content: Text('Вы уверены, что хотите передать ${selected.length} накладных на доставку?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Передать'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Передача накладных...'),
            ],
          ),
        ),
      );
      
      // Передаем все выбранные накладные
      for (final inv in selected) {
        await _invoiceService.updateInvoiceStatus(inv.id, InvoiceStatus.delivery);
      }
      
      // Закрываем индикатор загрузки
      Navigator.pop(context);
      
      // Обновляем данные и очищаем выбор
      _loadData();
      _clearSelection();
      
      // Показываем сообщение об успехе
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length} накладных передано на доставку'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  bool _isExporting = false;

  void _exportSelectedInvoicesToExcel() async {
    if (_isExporting) return; // Защита от множественных нажатий
    
    final selected = _filteredInvoices.where((inv) => _selectedInvoiceIds.contains(inv.id)).toList();
    if (selected.isEmpty) return;
    
    setState(() {
      _isExporting = true;
    });
    
    try {
      await ExcelExportService.exportInvoicesToExcel(
        invoices: selected,
        sheetName: 'Накладные на сборке',
        fileName: 'packing_invoices',
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
        title: Text('Накладные на сборке'),
        actions: [
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
                    onToday: () {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      setState(() {
                        _dateFrom = today;
                        _dateTo = today;
                      });
                    },
                    onTomorrow: () {
                      final now = DateTime.now().add(Duration(days: 1));
                      final tomorrow = DateTime(now.year, now.month, now.day);
                      setState(() {
                        _dateFrom = tomorrow;
                        _dateTo = tomorrow;
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
                                final total = _selectedInvoiceIds.isEmpty
                                    ? _filteredInvoices.fold<double>(0.0, (sum, inv) => sum + inv.totalAmount)
                                    : _filteredInvoices
                                        .where((inv) => _selectedInvoiceIds.contains(inv.id))
                                        .fold<double>(0.0, (sum, inv) => sum + inv.totalAmount);
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
                                icon: Icon(Icons.send),
                                label: Text('Передать все'),
                                onPressed: _transferAllSelected,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                icon: _isExporting 
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(Icons.share),
                                label: Text('Поделиться Excel'),
                                onPressed: _isExporting ? null : _exportSelectedInvoicesToExcel,
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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Точка: ${invoice.outletName}'),
                                  Text('Адрес: ${invoice.outletAddress}'),
                                  Text('Торговый: ${invoice.salesRepName}'),
                                  if (!_selectionMode) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => _showConfirmDialog(invoice),
                                          child: Text('Передать на доставку'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
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
                                ],
                              ),
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
  final VoidCallback onToday;
  final VoidCallback onTomorrow;
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
    required this.onToday,
    required this.onTomorrow,
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
            OutlinedButton(onPressed: onToday, child: Text('Сегодня')),
            OutlinedButton(onPressed: onTomorrow, child: Text('Завтра')),
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