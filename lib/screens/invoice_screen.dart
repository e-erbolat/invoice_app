import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';

class InvoiceScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceScreen({Key? key, required this.invoiceId}) : super(key: key);

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  Invoice? _invoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() { _isLoading = true; });
    final invoice = await _invoiceService.getInvoiceById(widget.invoiceId);
    setState(() {
      _invoice = invoice;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Детали накладной')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _invoice == null
              ? Center(child: Text('Накладная не найдена'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      Text('Накладная №${_invoice!.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Точка: ${_invoice!.outletName}'),
                      Text('Торговый: ${_invoice!.salesRepName}'),
                      Text('Дата: ${_invoice!.date.toDate()}'),
                      Text('Статус: ${_invoice!.status}'),
                      Text('Оплата: ${_invoice!.isPaid ? "Оплачен (${_invoice!.paymentType})" : _invoice!.isDebt ? "Долг" : "Не оплачен"}'),
                      Text('Принятие админом: ${_invoice!.acceptedByAdmin ? "Принял" : "Не принял"}'),
                      Text('Принятие суперадмином: ${_invoice!.acceptedBySuperAdmin ? "Принял" : "Не принял"}'),
                      Text('Сумма: ${_invoice!.totalAmount.toStringAsFixed(2)} ₸'),
                      SizedBox(height: 16),
                      Text('Товары:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._invoice!.items.map((item) => ListTile(
                        title: Text(item.productName),
                        subtitle: Text('${item.quantity} × ${item.price.toStringAsFixed(2)} ₸'),
                        trailing: Text('${item.totalPrice.toStringAsFixed(2)} ₸'),
                      )),
                    ],
                  ),
                ),
    );
  }
} 