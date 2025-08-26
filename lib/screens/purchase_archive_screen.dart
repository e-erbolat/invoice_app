import 'package:flutter/material.dart';
import '../models/purchase.dart';
import '../services/purchase_service.dart';
import 'purchase_detail_screen.dart';

class PurchaseArchiveScreen extends StatefulWidget {
  const PurchaseArchiveScreen({super.key});

  @override
  State<PurchaseArchiveScreen> createState() => _PurchaseArchiveScreenState();
}

class _PurchaseArchiveScreenState extends State<PurchaseArchiveScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  List<Purchase> _archivedPurchases = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArchivedPurchases();
  }

  Future<void> _loadArchivedPurchases() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Загружаем все закупы и фильтруем на клиенте, чтобы избежать проблем с индексами
      final allPurchases = await _purchaseService.getAllPurchases();
      if (mounted) {
        setState(() {
          _archivedPurchases = allPurchases.where((p) => p.status == PurchaseStatus.archived).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки архива: $e';
          _loading = false;
        });
      }
    }
  }

  void _openPurchaseDetails(Purchase purchase) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseDetailScreen(purchase: purchase),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Архив закупов'),
        backgroundColor: Colors.white,
        elevation: 2,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadArchivedPurchases,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadArchivedPurchases,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_archivedPurchases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Архив пуст',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Завершенные закупы появятся здесь',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadArchivedPurchases,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _archivedPurchases.length,
        itemBuilder: (context, index) {
          final purchase = _archivedPurchases[index];
          return _buildPurchaseCard(purchase);
        },
      ),
    );
  }

  Widget _buildPurchaseCard(Purchase purchase) {
    final date = purchase.dateCreated.toDate();
    final archivedDate = purchase.archivedAt?.toDate();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _openPurchaseDetails(purchase),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.archive, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      purchase.supplierName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(purchase.statusColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      purchase.statusDisplayName,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Создан: ${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (archivedDate != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.archive_outlined, color: Colors.grey[600], size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Архивирован: ${archivedDate.day.toString().padLeft(2,'0')}.${archivedDate.month.toString().padLeft(2,'0')}.${archivedDate.year}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.green[700], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Сумма: ${purchase.totalAmount.toStringAsFixed(2)} ₸',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${purchase.items.length} позиций',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, color: Colors.grey[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Создал: ${purchase.createdByUserName}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              if (purchase.notes != null && purchase.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, color: Colors.grey[600], size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        purchase.notes!,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Нажмите для просмотра деталей',
                    style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
