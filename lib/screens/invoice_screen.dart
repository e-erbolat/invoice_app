import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../services/invoice_service.dart';
import 'package:intl/intl.dart';

class InvoiceScreen extends StatefulWidget {
  final String invoiceId;
  final bool showAppBar;
  
  const InvoiceScreen({
    Key? key, 
    required this.invoiceId, 
    this.showAppBar = true,
  }) : super(key: key);

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
    if (mounted) {
      setState(() {
        _invoice = invoice;
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0: return Colors.red;      // cancelled
      case 1: return Colors.orange;   // review
      case 2: return Colors.blue;     // packing
      case 3: return Colors.purple;   // delivery
      case 4: return Colors.green;    // delivered
      case 5: return Colors.indigo;   // paymentChecked
      case 6: return Colors.grey;     // archive
      default: return Colors.grey;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0: return 'Отменен';
      case 1: return 'На рассмотрении';
      case 2: return 'На сборке';
      case 3: return 'На доставке';
      case 4: return 'Доставлен';
      case 5: return 'Проверка оплат';
      case 6: return 'Архив';
      default: return 'Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: Text('Детали накладной'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInvoice,
          ),
        ],
      ) : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _invoice == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Накладная не найдена', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInvoice,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Заголовок
                        _buildHeader(),
                        SizedBox(height: 24),
                        
                        // Основная информация
                        _buildMainInfo(),
                        SizedBox(height: 24),
                        
                        // Информация о торговой точке
                        _buildOutletInfo(),
                        SizedBox(height: 24),
                        
                        // Информация о торговом представителе
                        _buildSalesRepInfo(),
                        SizedBox(height: 24),
                        
                        // Статус и оплата
                        _buildStatusAndPayment(),
                        SizedBox(height: 24),
                        
                        // Список товаров
                        _buildItemsList(),
                        SizedBox(height: 24),
                        
                        // Итоговая сумма
                        _buildTotalAmount(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Накладная №${_invoice!.id}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            DateFormat('dd.MM.yyyy HH:mm').format(_invoice!.date.toDate()),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Основная информация',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow('ID накладной', _invoice!.id),
            _buildInfoRow('Дата создания', DateFormat('dd.MM.yyyy HH:mm').format(_invoice!.date.toDate())),
            _buildInfoRow('Количество товаров', '${_invoice!.items.length}'),
            _buildInfoRow('Количество позиций', '${_invoice!.items.where((item) => !item.isBonus).length}'),
            if (_invoice!.items.any((item) => item.isBonus))
              _buildInfoRow('Количество бонусов', '${_invoice!.items.where((item) => item.isBonus).length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  'Торговая точка',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow('Название', _invoice!.outletName),
            if (_invoice!.outletAddress.isNotEmpty)
              _buildInfoRow('Адрес', _invoice!.outletAddress),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesRepInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  'Торговый представитель',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow('Имя', _invoice!.salesRepName),
            _buildInfoRow('ID', _invoice!.salesRepId),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAndPayment() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статус и оплата',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_invoice!.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(_invoice!.status),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow('Статус оплаты', _invoice!.isPaid ? 'Оплачен' : _invoice!.isDebt ? 'Долг' : 'Не оплачен'),
            if (_invoice!.isPaid && _invoice!.paymentType != null)
              _buildInfoRow('Тип оплаты', _invoice!.paymentType!),
            if (_invoice!.isPaid) ...[
              _buildInfoRow('Принятие админом', _invoice!.acceptedByAdmin ? 'Принял' : 'Не принял'),
              _buildInfoRow('Принятие суперадмином', _invoice!.acceptedBySuperAdmin ? 'Принял' : 'Не принял'),
              if (_invoice!.acceptedAt != null)
                _buildInfoRow('Дата принятия', DateFormat('dd.MM.yyyy HH:mm').format(_invoice!.acceptedAt!.toDate())),
            ],
            if (_invoice!.bankAmount > 0)
              _buildInfoRow('Сумма по банку', '${_invoice!.bankAmount.toStringAsFixed(2)} ₸'),
            if (_invoice!.cashAmount > 0)
              _buildInfoRow('Сумма наличными', '${_invoice!.cashAmount.toStringAsFixed(2)} ₸'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    final regularItems = _invoice!.items.where((item) => !item.isBonus).toList();
    final bonusItems = _invoice!.items.where((item) => item.isBonus).toList();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Товары (${regularItems.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 16),
            if (regularItems.isNotEmpty) ...[
              ...regularItems.map((item) => _buildItemTile(item)),
              SizedBox(height: 16),
            ],
            if (bonusItems.isNotEmpty) ...[
              Text(
                'Бонусы (${bonusItems.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 8),
              ...bonusItems.map((item) => _buildBonusItemTile(item)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(InvoiceItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.satushiCode != null)
                  Text(
                    'Код: ${item.satushiCode}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              '${item.quantity} шт',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.price.toStringAsFixed(2)} ₸',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (item.hasDiscount) ...[
                  Text(
                    '${item.originalPrice.toStringAsFixed(2)} ₸',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    '-${item.discountPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ],
                Text(
                  '${item.totalPrice.toStringAsFixed(2)} ₸',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusItemTile(InvoiceItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              item.productName,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
            ),
          ),
          Text(
            '${item.quantity} шт',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmount() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Итоговая сумма',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${_invoice!.totalAmount.toStringAsFixed(2)} ₸',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 