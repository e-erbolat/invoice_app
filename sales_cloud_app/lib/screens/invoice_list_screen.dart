import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';
import '../models/outlet.dart';
import '../models/sales_rep.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;
import 'package:intl/intl.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String? selectedOutletId;
  String? selectedRepId;
  DateTime? selectedMonth;

  final invoicesRef = FirebaseFirestore.instance.collection('invoices');
  final outletsRef = FirebaseFirestore.instance.collection('outlets');
  final repsRef = FirebaseFirestore.instance.collection('sales_reps');

  Set<String> selectedInvoiceIds = {};
  bool selectionMode = false;
  
  // Шрифты для PDF
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  @override
  void initState() {
    super.initState();
    _loadFonts();
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

  void _toggleSelection(String invoiceId) {
    setState(() {
      if (selectedInvoiceIds.contains(invoiceId)) {
        selectedInvoiceIds.remove(invoiceId);
      } else {
        selectedInvoiceIds.add(invoiceId);
      }
      selectionMode = selectedInvoiceIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      selectedInvoiceIds.clear();
      selectionMode = false;
    });
  }

  Future<void> _exportSelectedInvoices(List<Invoice> allInvoices) async {
    final selected = allInvoices.where((inv) => selectedInvoiceIds.contains(inv.id)).toList();
    if (selected.isEmpty) return;
    final pdf = pw.Document();
    for (final inv in selected) {
      final page = await _generateInvoicePdf(inv);
      pdf.addPage(page.pages.first);
    }
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
    _clearSelection();
  }

  void _exportSelectedInvoicesToExcel(List<Invoice> allInvoices) async {
    final selected = allInvoices.where((inv) => selectedInvoiceIds.contains(inv.id)).toList();
    if (selected.isEmpty) return;
    
    // Создаем Excel документ
    final excel = Excel.createExcel();
    final sheet = excel['Накладные'];
    
    int currentRow = 0;
    
    for (int invoiceIndex = 0; invoiceIndex < selected.length; invoiceIndex++) {
      final invoice = selected[invoiceIndex];
      
      // Заголовок накладной (строка 1)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = 'MELLO AQTOBE';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = DateFormat('dd.MM.yyyy').format(invoice.date);
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
      if (invoiceIndex < selected.length - 1) {
        currentRow++;
      }
    }
    
    // Сохраняем файл
    final bytes = excel.save();
    if (bytes != null) {
      // Для веб-версии используем download
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'invoices.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Накладные')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: outletsRef.snapshots(),
                    builder: (context, snapshot) {
                      final outlets = snapshot.hasData ? snapshot.data!.docs.map((doc) => Outlet.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList() : [];
                      return DropdownButton<String?>(
                        value: selectedOutletId,
                        hint: Text('Торговая точка'),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: null, child: Text('Все точки')),
                          ...outlets.map((o) => DropdownMenuItem(value: o.id, child: Text(o.name)))
                        ],
                        onChanged: (v) => setState(() => selectedOutletId = v),
                      );
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: repsRef.snapshots(),
                    builder: (context, snapshot) {
                      final reps = snapshot.hasData ? snapshot.data!.docs.map((doc) => SalesRep.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList() : [];
                      return DropdownButton<String?>(
                        value: selectedRepId,
                        hint: Text('Представитель'),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: null, child: Text('Все представители')),
                          ...reps.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                        ],
                        onChanged: (v) => setState(() => selectedRepId = v),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.date_range),
                  tooltip: 'Выбрать месяц',
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedMonth ?? now,
                      firstDate: DateTime(now.year - 2),
                      lastDate: DateTime(now.year + 2),
                      helpText: 'Выберите месяц',
                      fieldLabelText: 'Месяц',
                      fieldHintText: 'ММ.ГГГГ',
                      initialEntryMode: DatePickerEntryMode.calendar,
                    );
                    if (picked != null) {
                      setState(() {
                        selectedMonth = DateTime(picked.year, picked.month);
                      });
                    }
                  },
                ),
                if (selectedMonth != null)
                  IconButton(
                    icon: Icon(Icons.clear),
                    tooltip: 'Сбросить месяц',
                    onPressed: () => setState(() => selectedMonth = null),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: invoicesRef.orderBy('date', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('Нет накладных'));
                  }
                  var invoices = snapshot.data!.docs.map((doc) => Invoice.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                  // Фильтрация
                  if (selectedOutletId != null) {
                    invoices = invoices.where((inv) => inv.outletId == selectedOutletId).toList();
                  }
                  if (selectedRepId != null) {
                    invoices = invoices.where((inv) => inv.salesRepId == selectedRepId).toList();
                  }
                  if (selectedMonth != null) {
                    invoices = invoices.where((inv) =>
                      inv.date.year == selectedMonth!.year &&
                      inv.date.month == selectedMonth!.month
                    ).toList();
                  }
                  return Column(
                    children: [
                      if (selectionMode)
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.picture_as_pdf),
                              label: Text('PDF'),
                              onPressed: () => _exportSelectedInvoices(invoices),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: Icon(Icons.table_chart),
                              label: Text('Excel'),
                              onPressed: () => _exportSelectedInvoicesToExcel(invoices),
                            ),
                            TextButton(
                              onPressed: _clearSelection,
                              child: Text('Отмена'),
                            ),
                          ],
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: invoices.length,
                          itemBuilder: (context, i) {
                            final inv = invoices[i];
                            final checked = selectedInvoiceIds.contains(inv.id);
                            return GestureDetector(
                              onLongPress: () => _toggleSelection(inv.id),
                              child: ListTile(
                                leading: selectionMode
                                    ? Checkbox(
                                        value: checked,
                                        onChanged: (_) => _toggleSelection(inv.id),
                                      )
                                    : null,
                                title: Text(inv.outletName),
                                subtitle: Text('Дата: \n${inv.date.toLocal().toString().substring(0, 10)} | Сумма: ${inv.totalAmount.toStringAsFixed(2)}'),
                                onTap: selectionMode
                                    ? () => _toggleSelection(inv.id)
                                    : () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Детали накладной'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Торговая точка: ${inv.outletName}'),
                                                Text('Дата: ${inv.date.toLocal().toString().substring(0, 10)}'),
                                                Text('Сумма: ${inv.totalAmount.toStringAsFixed(2)}'),
                                                SizedBox(height: 8),
                                                Text('Товары:'),
                                                ...inv.items.map((item) => Text(
                                                  '- ${item.productName} x${item.quantity} | Цена: ${item.price} | Скидка: ${item.discount}${item.isBonus ? ' (Бонус)' : ''}'
                                                )),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () async {
                                                  final pdf = await _generateInvoicePdf(inv);
                                                  await Printing.layoutPdf(onLayout: (format) => pdf.save());
                                                },
                                                child: Text('Экспорт/Печать'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text('Закрыть'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<pw.Document> _generateInvoicePdf(Invoice inv) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Накладная', 
              style: pw.TextStyle(fontSize: 24, font: _boldFont)),
            pw.SizedBox(height: 8),
            pw.Text('Торговая точка: ${inv.outletName}', 
              style: pw.TextStyle(font: _regularFont)),
            pw.Text('Дата: ${inv.date.toLocal().toString().substring(0, 10)}', 
              style: pw.TextStyle(font: _regularFont)),
            pw.Text('Сумма: ${inv.totalAmount.toStringAsFixed(2)}', 
              style: pw.TextStyle(font: _regularFont)),
            pw.SizedBox(height: 16),
            pw.Text('Товары:', 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: _boldFont)),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text('Товар', style: pw.TextStyle(font: _boldFont))),
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text('Кол-во', style: pw.TextStyle(font: _boldFont))),
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text('Цена', style: pw.TextStyle(font: _boldFont))),
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text('Скидка', style: pw.TextStyle(font: _boldFont))),
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text('Бонус', style: pw.TextStyle(font: _boldFont))),
                  ],
                ),
                ...inv.items.map((item) => pw.TableRow(
                  children: [
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text(item.productName, style: pw.TextStyle(font: _regularFont))),
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text(item.quantity.toString(), style: pw.TextStyle(font: _regularFont))),
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text(item.price.toString(), style: pw.TextStyle(font: _regularFont))),
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text(item.discount.toString(), style: pw.TextStyle(font: _regularFont))),
                    pw.Padding(padding: pw.EdgeInsets.all(4), 
                      child: pw.Text(item.isBonus ? 'Да' : '', style: pw.TextStyle(font: _regularFont))), 
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text('Итого к оплате: ${inv.totalAmount.toStringAsFixed(2)}', 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: _boldFont)),
          ],
        ),
      ),
    );
    return pdf;
  }
} 