import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvoiceScreen extends StatefulWidget {
  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  List<Map<String, dynamic>> items = [];
  final TextEditingController itemController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController bonusController = TextEditingController();
  final TextEditingController pointController = TextEditingController();

  double get total {
    double sum = 0;
    for (var item in items) {
      sum += (item['qty'] * item['price']) - item['discount'];
    }
    return sum;
  }

  void addItem() {
    if (itemController.text.isEmpty ||
        qtyController.text.isEmpty ||
        priceController.text.isEmpty) return;

    setState(() {
      items.add({
        'name': itemController.text,
        'qty': int.tryParse(qtyController.text) ?? 0,
        'price': double.tryParse(priceController.text) ?? 0.0,
        'discount': double.tryParse(discountController.text) ?? 0.0,
        'bonus': bonusController.text,
      });
    });

    itemController.clear();
    qtyController.clear();
    priceController.clear();
    discountController.clear();
    bonusController.clear();
  }

  void saveInvoice() {
    String summary = "Точка: ${pointController.text}
Дата: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}
";
    for (var item in items) {
      summary +=
          "${item['name']} - ${item['qty']} x ${item['price']} - скидка ${item['discount']} - бонус: ${item['bonus'] ?? ''}
";
    }
    summary += "Итого: $total";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Сохранено"),
        content: Text(summary),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Новая накладная")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: pointController, decoration: InputDecoration(labelText: "Торговая точка")),
            Divider(),
            TextField(controller: itemController, decoration: InputDecoration(labelText: "Товар")),
            TextField(controller: qtyController, decoration: InputDecoration(labelText: "Количество"), keyboardType: TextInputType.number),
            TextField(controller: priceController, decoration: InputDecoration(labelText: "Цена"), keyboardType: TextInputType.number),
            TextField(controller: discountController, decoration: InputDecoration(labelText: "Скидка"), keyboardType: TextInputType.number),
            TextField(controller: bonusController, decoration: InputDecoration(labelText: "Бонус (если есть)")),
            SizedBox(height: 10),
            ElevatedButton(onPressed: addItem, child: Text("Добавить товар")),
            Divider(),
            ...items.map((item) => ListTile(
                  title: Text("${item['name']} (${item['qty']} x ${item['price']})"),
                  subtitle: Text("Скидка: ${item['discount']} | Бонус: ${item['bonus'] ?? ''}"),
                )),
            Divider(),
            Text("Итого: $total", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            ElevatedButton(onPressed: saveInvoice, child: Text("Сохранить накладную")),
          ],
        ),
      ),
    );
  }
}