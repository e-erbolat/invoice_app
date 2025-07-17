import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';
import '../models/sales_rep.dart';
import '../models/outlet.dart';

class SalesRepReportScreen extends StatefulWidget {
  const SalesRepReportScreen({Key? key}) : super(key: key);

  @override
  State<SalesRepReportScreen> createState() => _SalesRepReportScreenState();
}

class _SalesRepReportScreenState extends State<SalesRepReportScreen> {
  DateTime? selectedMonth;
  final repsRef = FirebaseFirestore.instance.collection('sales_reps');
  final invoicesRef = FirebaseFirestore.instance.collection('invoices');
  final outletsRef = FirebaseFirestore.instance.collection('outlets');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Отчёт по представителям')),
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
                stream: repsRef.snapshots(),
                builder: (context, repSnap) {
                  if (!repSnap.hasData) return Center(child: CircularProgressIndicator());
                  final reps = repSnap.data!.docs.map((doc) => SalesRep.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
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
                        itemCount: reps.length,
                        itemBuilder: (context, i) {
                          final rep = reps[i];
                          final repInvoices = invoices.where((inv) => inv.salesRepId == rep.id).toList();
                          final total = repInvoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
                          // Считаем торговые точки и количество заказов
                          final Map<String, int> outletCounts = {};
                          for (var inv in repInvoices) {
                            outletCounts[inv.outletName] = (outletCounts[inv.outletName] ?? 0) + 1;
                          }
                          final outletList = outletCounts.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value));
                          return Card(
                            child: ExpansionTile(
                              title: Text(rep.name),
                              subtitle: Text('Сумма заказов: ${total.toStringAsFixed(2)}'),
                              children: [
                                if (outletList.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Нет заказов'),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: outletList.map((e) => Text('${e.key}: ${e.value} заказ(ов)')).toList(),
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