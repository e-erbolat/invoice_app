import 'package:flutter/material.dart';
import '../models/procurement.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final Procurement procurement;
  const PurchaseDetailScreen({Key? key, required this.procurement}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final date = procurement.date.toDate();
    return Scaffold(
      appBar: AppBar(title: const Text('Детали закупа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Источник: ${procurement.sourceName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Дата: ${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}'),
            const SizedBox(height: 8),
            Text('Итого: ${procurement.totalAmount.toStringAsFixed(2)} ₸', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Text('Позиции', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: procurement.items.length,
                itemBuilder: (context, i) {
                  final it = procurement.items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(it.productName),
                      subtitle: Text('${it.quantity} × ${it.purchasePrice.toStringAsFixed(2)} = ${it.totalPrice.toStringAsFixed(2)} ₸'),
                    ),
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


