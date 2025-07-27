import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import '../services/cash_register_service.dart';
import '../models/cash_register.dart';

class AdminPaymentCheckInvoicesScreen extends StatefulWidget {
  const AdminPaymentCheckInvoicesScreen({Key? key}) : super(key: key);
  @override
  State<AdminPaymentCheckInvoicesScreen> createState() => _AdminPaymentCheckInvoicesScreenState();
}

class _AdminPaymentCheckInvoicesScreenState extends State<AdminPaymentCheckInvoicesScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final CashRegisterService _cashRegisterService = CashRegisterService();
  AppUser? _currentUser;
  List<Invoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    setState(() { _isLoading = true; });
    final user = await AuthService().getCurrentUser();
    final invoices = await _invoiceService.getInvoicesByStatus(InvoiceStatus.paymentChecked);
    setState(() {
      _currentUser = user;
      _invoices = invoices;
      _isLoading = false;
    });
  }

  Future<void> _confirmInvoice(Invoice invoice) async {
    setState(() { _isLoading = true; });
    
    try {
      // Обновляем статус накладной
      await _invoiceService.updateInvoice(invoice.copyWith(
        status: InvoiceStatus.archive,
        acceptedBySuperAdmin: true,
      ));
      
      // Если есть наличные деньги, записываем их в кассу
      final cashAmount = invoice.cashAmount;
      if (cashAmount > 0) {
        final cashRecord = CashRegister(
          id: _cashRegisterService.generateRecordId(),
          date: DateTime.now(),
          amount: cashAmount,
          description: 'Поступление от накладной ${invoice.id}',
          invoiceId: invoice.id,
        );
        await _cashRegisterService.addCashRecord(cashRecord);
      }
      
      await _loadUserAndData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при подтверждении накладной: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Проверка оплат')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? Center(child: Text('Нет накладных для проверки оплат'))
              : ListView.builder(
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _invoices[index];
                    final date = invoice.date.toDate();
                    final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        title: Text('Накладная ${invoice.id}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Точка: ${invoice.outletName}'),
                            Text('Адрес: ${invoice.outletAddress}'),
                            Text('Торговый: ${invoice.salesRepName}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Банк: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('${(invoice.toMap()['bankAmount'] ?? 0.0).toStringAsFixed(2)} ₸', style: TextStyle(color: Colors.deepPurple)),
                                const SizedBox(width: 16),
                                Text('Наличные: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('${(invoice.toMap()['cashAmount'] ?? 0.0).toStringAsFixed(2)} ₸', style: TextStyle(color: Colors.deepPurple)),
                              ],
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${invoice.totalAmount.toStringAsFixed(2)} ₸', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            if (_currentUser?.role == 'superadmin')
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton(
                                  onPressed: () => _confirmInvoice(invoice),
                                  child: const Text('Подтвердить'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 