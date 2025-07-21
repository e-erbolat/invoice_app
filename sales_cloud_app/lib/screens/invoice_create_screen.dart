import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/outlet.dart';
import '../models/sales_rep.dart';
import '../models/invoice_item.dart';

class InvoiceCreateScreen extends StatefulWidget {
  const InvoiceCreateScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  Outlet? selectedOutlet;
  SalesRep? selectedRep;
  List<InvoiceItem> items = [];

  final outletsRef = FirebaseFirestore.instance.collection('outlets');
  final repsRef = FirebaseFirestore.instance.collection('sales_reps');
  final productsRef = FirebaseFirestore.instance.collection('products');
  final invoicesRef = FirebaseFirestore.instance.collection('invoices');

  void _addProductDialog(List<Product> products) {
    Product? selectedProduct;
    final qtyController = TextEditingController(text: '1');
    final discountController = TextEditingController(text: '0');
    bool isBonus = false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Добавить товар'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              value: selectedProduct,
              items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (p) => setState(() => selectedProduct = p),
              decoration: InputDecoration(labelText: 'Товар'),
            ),
            TextField(
              controller: qtyController,
              decoration: InputDecoration(labelText: 'Количество'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: discountController,
              decoration: InputDecoration(labelText: 'Скидка'),
              keyboardType: TextInputType.number,
            ),
            CheckboxListTile(
              value: isBonus,
              onChanged: (v) => setState(() => isBonus = v ?? false),
              title: Text('Бонус (подарок)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedProduct != null) {
                final qty = int.tryParse(qtyController.text) ?? 1;
                final discount = double.tryParse(discountController.text) ?? 0;
                items.add(InvoiceItem(
                  productId: selectedProduct!.id,
                  productName: selectedProduct!.name,
                  quantity: qty,
                  price: isBonus ? 0 : selectedProduct!.price,
                  discount: discount,
                  isBonus: isBonus,
                ));
                setState(() {});
                Navigator.pop(context);
              }
            },
            child: Text('Добавить'),
          ),
        ],
      ),
    );
  }

  double get totalAmount => items.fold(0, (sum, item) => sum + (item.isBonus ? 0 : (item.price - item.discount) * item.quantity));

  void _saveInvoice() async {
    if (selectedOutlet == null || selectedRep == null || items.isEmpty) return;
    await invoicesRef.add({
      'outletId': selectedOutlet!.id,
      'outletName': selectedOutlet!.name,
      'salesRepId': selectedRep!.id,
      'date': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Создать накладную')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: outletsRef.snapshots(),
                builder: (context, snapshot) {
                  final outlets = snapshot.hasData ? snapshot.data!.docs.map((doc) => Outlet.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList() : [];
                  return DropdownButtonFormField<Outlet>(
                    value: selectedOutlet,
                    items: outlets.map((o) => DropdownMenuItem(value: o, child: Text(o.name))).toList(),
                    onChanged: (o) => setState(() => selectedOutlet = o),
                    decoration: InputDecoration(labelText: 'Торговая точка'),
                  );
                },
              ),
              SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: repsRef.snapshots(),
                builder: (context, snapshot) {
                  final reps = snapshot.hasData ? snapshot.data!.docs.map((doc) => SalesRep.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList() : [];
                  return DropdownButtonFormField<SalesRep>(
                    value: selectedRep,
                    items: reps.map((r) => DropdownMenuItem(value: r, child: Text(r.name))).toList(),
                    onChanged: (r) => setState(() => selectedRep = r),
                    decoration: InputDecoration(labelText: 'Торговый представитель'),
                  );
                },
              ),
              SizedBox(height: 16),
              Text('Товары в накладной:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return ListTile(
                    title: Text(item.productName),
                    subtitle: Text('Кол-во: ${item.quantity}, Цена: ${item.price}, Скидка: ${item.discount}${item.isBonus ? ' (Бонус)' : ''}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          items.removeAt(i);
                        });
                      },
                    ),
                  );
                },
              ),
              SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: productsRef.snapshots(),
                builder: (context, snapshot) {
                  final products = snapshot.hasData ? snapshot.data!.docs.map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList() : [];
                  return ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Добавить товар'),
                    onPressed: products.isEmpty ? null : () => _addProductDialog(products),
                  );
                },
              ),
              SizedBox(height: 16),
              Text('Итого к оплате: ${totalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: (selectedOutlet != null && selectedRep != null && items.isNotEmpty) ? _saveInvoice : null,
                  child: Text('Сохранить накладную'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 