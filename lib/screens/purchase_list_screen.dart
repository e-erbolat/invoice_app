import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase.dart';
import '../services/purchase_service.dart';
import 'purchase_create_screen.dart';
import 'purchase_detail_screen.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  List<Purchase> _purchases = [];
  bool _isLoading = true;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final purchases = await _purchaseService.getPurchases(status: _selectedStatus);
      setState(() {
        _purchases = purchases;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки закупов: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Закупы'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (status) {
              setState(() => _selectedStatus = status == 'all' ? null : status);
              _loadPurchases();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Все статусы')),
              ...Purchase.allStatuses.map((status) => PopupMenuItem(
                value: status,
                child: Text(_getStatusDisplayName(status)),
              )),
            ],
            child: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: _loadPurchases,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
              ? const Center(
                  child: Text(
                    'Нет закупов',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPurchases,
                  child: ListView.builder(
                    itemCount: _purchases.length,
                    itemBuilder: (context, index) {
                      final purchase = _purchases[index];
                      return _buildPurchaseCard(purchase);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PurchaseCreateScreen()),
          );
          if (result == true) {
            _loadPurchases();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPurchaseCard(Purchase purchase) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          'Закуп от ${purchase.supplierName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Дата: ${_formatDate(purchase.dateCreated)}'),
            Text('Сумма: ${purchase.totalAmount.toStringAsFixed(2)} ₽'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(purchase.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                purchase.statusDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PurchaseDetailScreen(purchaseId: purchase.id),
            ),
          );
          if (result == true) {
            _loadPurchases();
          }
        },
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case Purchase.statusCreated:
        return Colors.blue;
      case Purchase.statusReceiving:
        return Colors.orange;
      case Purchase.statusInStock:
        return Colors.purple;
      case Purchase.statusOnSale:
        return Colors.green;
      case Purchase.statusCompleted:
        return Colors.teal;
      case Purchase.statusClosedWithShortage:
        return Colors.red;
      case Purchase.statusArchived:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case Purchase.statusCreated:
        return 'Создан';
      case Purchase.statusReceiving:
        return 'Приемка';
      case Purchase.statusInStock:
        return 'На складе';
      case Purchase.statusOnSale:
        return 'В продаже';
      case Purchase.statusCompleted:
        return 'Завершен';
      case Purchase.statusClosedWithShortage:
        return 'Закрыт с недостачей';
      case Purchase.statusArchived:
        return 'В архиве';
      default:
        return status;
    }
  }
}