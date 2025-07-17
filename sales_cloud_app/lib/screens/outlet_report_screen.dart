import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';
import '../models/outlet.dart';

class OutletReportScreen extends StatefulWidget {
  const OutletReportScreen({Key? key}) : super(key: key);

  @override
  State<OutletReportScreen> createState() => _OutletReportScreenState();
}

class _OutletReportScreenState extends State<OutletReportScreen> {
  DateTime? selectedMonth;
  final outletsRef = FirebaseFirestore.instance.collection('outlets');
  final invoicesRef = FirebaseFirestore.instance.collection('invoices');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Отчёт по торговым точкам')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('Месяц: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(selectedMonth != null
                    ? '${selectedMonth!.month.toString().padLeft(2, '0')}.${selectedMonth!.year}'
                    : 'Все'),
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
                stream: outletsRef.snapshots(),
                builder: (context, outletSnap) {
                  if (!outletSnap.hasData) return Center(child: CircularProgressIndicator());
                  final outlets = outletSnap.data!.docs.map((doc) => Outlet.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                  return StreamBuilder<QuerySnapshot>(
                    stream: invoicesRef.snapshots(),
                    builder: (context, invSnap) {
                      if (!invSnap.hasData) return Center(child: CircularProgressIndicator());
                      var invoices = invSnap.data!.docs.map((doc) => Invoice.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                      if (selectedMonth != null) {
                        invoices = invoices.where((inv) =>
                          inv.date.year == selectedMonth!.year &&
                          inv.date.month == selectedMonth!.month
                        ).toList();
                      }
                      return ListView.builder(
                        itemCount: outlets.length,
                        itemBuilder: (context, i) {
                          final outlet = outlets[i];
                          final outletInvoices = invoices.where((inv) => inv.outletId == outlet.id).toList();
                          final total = outletInvoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
                          // Считаем товары
                          final Map<String, int> productCounts = {};
                          for (var inv in outletInvoices) {
                            for (var item in inv.items) {
                              productCounts[item.productName] = (productCounts[item.productName] ?? 0) + item.quantity;
                            }
                          }
                          final topProducts = productCounts.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value));
                          return Card(
                            child: ExpansionTile(
                              title: Text(outlet.name),
                              subtitle: Text('Сумма заказов: ${total.toStringAsFixed(2)}'),
                              children: [
                                if (topProducts.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Нет заказов'),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: topProducts.map((e) => Text('${e.key}: ${e.value} шт.')).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 