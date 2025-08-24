import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../models/sales_rep.dart';
import '../services/firebase_service.dart';
import 'invoice_screen.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'invoice_create_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../models/outlet.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/excel_export_service.dart';

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
  List<Outlet> _outlets = [];
  bool _isLoading = true;
  String? _selectedSalesRepId;
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
        print('[AdminIncomingInvoicesScreen] Текущий пользователь: uid= [33m${user.uid} [0m, role=${user.role}, salesRepId=${user.salesRepId}');
        if (user.salesRepId == null) throw Exception('У пользователя не заполнен salesRepId!');
        invoices = await _invoiceService.getInvoicesByStatusAndSalesRepSimple(InvoiceStatus.review, user.salesRepId!);
      } else {
        invoices = await _invoiceService.getInvoicesByStatus(InvoiceStatus.review);
      }
      print('[DEBUG] Загружено накладных: ${invoices.length}');
      for (final inv in invoices) {
        print('[DEBUG] Invoice id=${inv.id}, status=${inv.status} (type: ${inv.status.runtimeType}), salesRepId=${inv.salesRepId}, outletId=${inv.outletId}');
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
                await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.packing);
                _loadData();
              },
              child: Text('Принять'),
            ),
          ],
        ),
      );
    }
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
        sheetName: 'Входящие накладные',
        fileName: 'incoming_invoices',
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
        title: Text('Входящие накладные'),
        actions: [
          IconButton(
            icon: _isExporting 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share),
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
                              OutlinedButton(
                                onPressed: _clearFilters,
                                child: Text('Сбросить фильтры'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (context) {
                            final total = _filteredInvoices.fold<double>(0.0, (sum, inv) => sum + inv.totalAmount);
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
                  ),
                Expanded(
                  child: _filteredInvoices.isEmpty
                      ? Center(child: Text('Нет входящих накладных'))
                                              : ListView.builder(
                            itemCount: _filteredInvoices.length,
                            itemBuilder: (context, index) {
                              final invoice = _filteredInvoices[index];
                              
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
                                          const Text(
                                            'Общая сумма:',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepPurple,
                                            ),
                                          ),
                                          Text(
                                            '${totalSum.toStringAsFixed(2)} ₸',
                                            style: const TextStyle(
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
    // Извлекаем 4 последних цифры из id, если они есть, иначе просто индекс+1
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
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Номер и дата
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Основная информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Накладная $customNumber', maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Точка: ${invoice.outletName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Адрес: ${invoice.outletAddress}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Торговый: ${invoice.salesRepName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Сумма и кнопки для веб-версии
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${invoice.totalAmount.toStringAsFixed(2)} ₸',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      fontSize: 16,
                    ),
                  ),
                  // Кнопки для веб-версии
                  if (kIsWeb && invoice.status == InvoiceStatus.review) ...[
                    SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                                                 IconButton(
                           icon: Icon(Icons.edit, color: Colors.deepPurple),
                          tooltip: 'Редактировать',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoiceCreateScreen(invoiceToEdit: invoice),
                              ),
                            ).then((_) => _loadData());
                          },
                        ),
                        if (!widget.forSales)
                                                     IconButton(
                             icon: Icon(Icons.check_circle, color: Colors.green),
                            tooltip: 'Принять',
                            onPressed: () async {
                              await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.packing);
                              _loadData();
                            },
                          ),
                                                 IconButton(
                           icon: Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Отклонить',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Отклонить накладную?'),
                                content: Text('Вы уверены, что хотите отклонить (удалить) накладную?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Отмена')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Отклонить')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _invoiceService.deleteInvoice(invoice.id);
                              _loadData();
                            }
                          },
                        ),
                        if (widget.forSales)
                                                     IconButton(
                             icon: Icon(Icons.share, color: Colors.blue),
                            tooltip: 'Поделиться',
                            onPressed: () {
                              final outlet = _outlets.firstWhere(
                                (o) => o.id == invoice.outletId,
                                orElse: () => Outlet(
                                  id: '',
                                  name: invoice.outletName,
                                  address: invoice.outletAddress,
                                  phone: '',
                                  contactPerson: '',
                                  region: '',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ),
                              );
                              final buffer = StringBuffer();
                              buffer.writeln('${outlet.name}');
                              buffer.writeln('Адрес: ${outlet.address}');
                              if (outlet.contactPerson.isNotEmpty || outlet.phone.isNotEmpty) {
                                buffer.writeln('${outlet.contactPerson} ${outlet.phone}'.trim());
                              }
                              for (final item in invoice.items.where((i) => !i.isBonus)) {
                                buffer.writeln('${item.productName} - ${item.quantity} шт х ${item.price.toStringAsFixed(0)} тг');
                              }
                              final bonusItems = invoice.items.where((i) => i.isBonus).toList();
                              if (bonusItems.isNotEmpty) {
                                buffer.writeln('\nБонус:');
                                for (final item in bonusItems) {
                                  buffer.writeln('${item.productName} - ${item.quantity} шт');
                                }
                              }
                              buffer.writeln('Итого: ${invoice.totalAmount.toStringAsFixed(0)} тг');
                              Share.share(buffer.toString());
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          // Кнопки внизу для мобильных устройств
          if (!kIsWeb && invoice.status == InvoiceStatus.review) ...[
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.deepPurple),
                    tooltip: 'Редактировать',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoiceCreateScreen(invoiceToEdit: invoice),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                  if (!widget.forSales) ...[
                    SizedBox(width: 16),
                    IconButton(
                      icon: Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Принять',
                      onPressed: () async {
                        await _invoiceService.updateInvoiceStatus(invoice.id, InvoiceStatus.packing);
                        _loadData();
                      },
                    ),
                  ],
                  SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Отклонить',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Отклонить накладную?'),
                          content: Text('Вы уверены, что хотите отклонить (удалить) накладную?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Отмена')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Отклонить')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _invoiceService.deleteInvoice(invoice.id);
                        _loadData();
                      }
                    },
                  ),
                  if (widget.forSales) ...[
                    SizedBox(width: 16),
                    IconButton(
                      icon: Icon(Icons.share, color: Colors.blue),
                      tooltip: 'Поделиться',
                      onPressed: () {
                        final outlet = _outlets.firstWhere(
                          (o) => o.id == invoice.outletId,
                          orElse: () => Outlet(
                            id: '',
                            name: invoice.outletName,
                            address: invoice.outletAddress,
                            phone: '',
                            contactPerson: '',
                            region: '',
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                        final buffer = StringBuffer();
                        buffer.writeln('${outlet.name}');
                        buffer.writeln('Адрес: ${outlet.address}');
                        if (outlet.contactPerson.isNotEmpty || outlet.phone.isNotEmpty) {
                          buffer.writeln('${outlet.contactPerson} ${outlet.phone}'.trim());
                        }
                        for (final item in invoice.items.where((i) => !i.isBonus)) {
                          buffer.writeln('${item.productName} - ${item.quantity} шт х ${item.price.toStringAsFixed(0)} тг');
                        }
                        final bonusItems = invoice.items.where((i) => i.isBonus).toList();
                        if (bonusItems.isNotEmpty) {
                          buffer.writeln('\nБонус:');
                          for (final item in bonusItems) {
                            buffer.writeln('${item.productName} - ${item.quantity} шт');
                          }
                        }
                        buffer.writeln('Итого: ${invoice.totalAmount.toStringAsFixed(0)} тг');
                        Share.share(buffer.toString());
                      },
                    ),
                  ],
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