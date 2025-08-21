import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/shortage.dart';
import '../models/purchase_log.dart';
import '../services/purchase_service.dart';
import 'purchase_receiving_screen.dart';
import 'purchase_stocking_screen.dart';
import 'purchase_sale_screen.dart';
import 'shortage_management_screen.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final String purchaseId;

  const PurchaseDetailScreen({Key? key, required this.purchaseId}) : super(key: key);

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> with SingleTickerProviderStateMixin {
  final PurchaseService _purchaseService = PurchaseService();
  
  Purchase? _purchase;
  List<PurchaseItem> _items = [];
  List<Shortage> _shortages = [];
  List<PurchaseLog> _logs = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPurchaseData();
  }

  Future<void> _loadPurchaseData() async {
    setState(() => _isLoading = true);
    try {
      final purchase = await _purchaseService.getPurchaseById(widget.purchaseId);
      final items = await _purchaseService.getPurchaseItems(widget.purchaseId);
      final shortages = await _purchaseService.getShortages(purchaseId: widget.purchaseId);
      final logs = await _purchaseService.getPurchaseLogs(widget.purchaseId);
      final statistics = await _purchaseService.getPurchaseStatistics(widget.purchaseId);

      setState(() {
        _purchase = purchase;
        _items = items;
        _shortages = shortages;
        _logs = logs;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _purchase == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Закуп #${_purchase!.id.substring(0, 8)}'),
        actions: [
          IconButton(
            onPressed: _loadPurchaseData,
            icon: const Icon(Icons.refresh),
          ),
          _buildActionButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Обзор', icon: Icon(Icons.dashboard)),
            Tab(text: 'Товары', icon: Icon(Icons.inventory)),
            Tab(text: 'Недостачи', icon: Icon(Icons.warning)),
            Tab(text: 'История', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildItemsTab(),
          _buildShortagesTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    switch (_purchase!.status) {
      case Purchase.statusCreated:
        return TextButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseReceivingScreen(purchaseId: widget.purchaseId),
              ),
            );
            if (result == true) _loadPurchaseData();
          },
          child: const Text('Приемка', style: TextStyle(color: Colors.white)),
        );
      
      case Purchase.statusReceiving:
      case Purchase.statusInStock:
        return PopupMenuButton<String>(
          onSelected: (action) async {
            bool? result;
            switch (action) {
              case 'stock':
                result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchaseStockingScreen(purchaseId: widget.purchaseId),
                  ),
                );
                break;
              case 'sale':
                result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchaseSaleScreen(purchaseId: widget.purchaseId),
                  ),
                );
                break;
            }
            if (result == true) _loadPurchaseData();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'stock', child: Text('Оприходовать')),
            const PopupMenuItem(value: 'sale', child: Text('Выставить на продажу')),
          ],
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildStatisticsCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Информация о закупе',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Поставщик', _purchase!.supplierName),
            _buildInfoRow('Дата создания', _formatDate(_purchase!.dateCreated)),
            _buildInfoRow('Статус', _purchase!.statusDisplayName),
            _buildInfoRow('Общая сумма', '${_purchase!.totalAmount.toStringAsFixed(2)} ₽'),
            if (_purchase!.notes != null) _buildInfoRow('Примечания', _purchase!.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статистика',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildStatRow('Заказано товаров', '${_statistics['totalItemsOrdered']} шт'),
            _buildStatRow('Получено товаров', '${_statistics['totalItemsReceived']} шт'),
            _buildStatRow('Недостача', '${_statistics['totalItemsMissing']} шт'),
            _buildStatRow('Сумма заказа', '${_statistics['totalAmountOrdered']?.toStringAsFixed(2) ?? '0'} ₽'),
            _buildStatRow('Сумма получено', '${_statistics['totalAmountReceived']?.toStringAsFixed(2) ?? '0'} ₽'),
            _buildStatRow('Сумма недостачи', '${_statistics['totalAmountMissing']?.toStringAsFixed(2) ?? '0'} ₽'),
            _buildStatRow('Выполнение', '${_statistics['completionPercentage']?.toStringAsFixed(1) ?? '0'}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item.productName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Заказано: ${item.orderedQty} шт'),
                Text('Получено: ${item.receivedQty} шт'),
                if (item.missingQty > 0) Text('Недостача: ${item.missingQty} шт', style: const TextStyle(color: Colors.red)),
                Text('Сумма: ${item.totalOrderedAmount.toStringAsFixed(2)} ₽'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getItemStatusColor(item.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.statusDisplayName,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShortagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Недостачи (${_shortages.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_shortages.any((s) => s.status == Shortage.statusWaiting))
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShortageManagementScreen(purchaseId: widget.purchaseId),
                      ),
                    );
                    if (result == true) _loadPurchaseData();
                  },
                  child: const Text('Управление'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _shortages.isEmpty
              ? const Center(child: Text('Нет недостач'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _shortages.length,
                  itemBuilder: (context, index) {
                    final shortage = _shortages[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(shortage.productName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Недостача: ${shortage.missingQty} шт'),
                            Text('Сумма: ${shortage.totalMissingAmount.toStringAsFixed(2)} ₽'),
                            Text('Создано: ${_formatDate(shortage.dateCreated)}'),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getShortageStatusColor(shortage.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            shortage.statusDisplayName,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(_getActionIcon(log.action)),
            title: Text(log.actionDisplayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Дата: ${_formatDate(log.date)}'),
                Text('Пользователь: ${log.userName}'),
                if (log.notes != null) Text('Примечания: ${log.notes}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getItemStatusColor(String status) {
    switch (status) {
      case PurchaseItem.statusOrdered:
        return Colors.blue;
      case PurchaseItem.statusReceived:
        return Colors.orange;
      case PurchaseItem.statusInStock:
        return Colors.purple;
      case PurchaseItem.statusOnSale:
        return Colors.green;
      case PurchaseItem.statusShortageWaiting:
        return Colors.red;
      case PurchaseItem.statusShortageReceived:
        return Colors.teal;
      case PurchaseItem.statusShortageNotReceived:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getShortageStatusColor(String status) {
    switch (status) {
      case Shortage.statusWaiting:
        return Colors.orange;
      case Shortage.statusReceived:
        return Colors.green;
      case Shortage.statusNotReceived:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case PurchaseLog.actionCreated:
        return Icons.add_circle;
      case PurchaseLog.actionReceived:
        return Icons.local_shipping;
      case PurchaseLog.actionShortageRecorded:
        return Icons.warning;
      case PurchaseLog.actionStocked:
        return Icons.warehouse;
      case PurchaseLog.actionOnSale:
        return Icons.store;
      case PurchaseLog.actionShortageReceived:
        return Icons.check_circle;
      case PurchaseLog.actionShortageNotReceived:
        return Icons.cancel;
      case PurchaseLog.actionArchived:
        return Icons.archive;
      default:
        return Icons.info;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}