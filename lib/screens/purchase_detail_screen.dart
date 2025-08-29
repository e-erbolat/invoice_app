import 'package:flutter/material.dart';
import '../models/purchase.dart';
import '../models/shortage.dart';
import '../services/purchase_service.dart';
import '../services/shortage_service.dart';
import '../services/auth_service.dart';
import '../services/satushi_api_service.dart';
import '../models/app_user.dart';
import 'goods_receiving_screen.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final Purchase purchase;
  const PurchaseDetailScreen({super.key, required this.purchase});

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  final ShortageService _shortageService = ShortageService();
  final AuthService _authService = AuthService();
  final SatushiApiService _satushiApiService = SatushiApiService();
  AppUser? _currentUser;
  List<Shortage> _shortages = [];
  bool _loadingShortages = false;
  bool _stockingInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadShortages();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _loadShortages() async {
    setState(() { _loadingShortages = true; });
    try {
      // Сначала очищаем дубликаты
      await _shortageService.removeDuplicateShortages(widget.purchase.id);
      
      // Затем загружаем недостачи
      final shortages = await _shortageService.getShortagesByPurchaseId(widget.purchase.id);
      if (mounted) {
        setState(() {
          _shortages = shortages;
          _loadingShortages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loadingShortages = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки недостач: $e')),
        );
      }
    }
  }

  /// Оприходовать товары закупа через API Satushi и принять на склад
  Future<void> _stockItems() async {
    if (_currentUser?.satushiToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: отсутствует токен Satushi в профиле'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() { _stockingInProgress = true; });
      
      // Получаем актуальные данные закупа перед отправкой в API
      debugPrint('[PurchaseDetailScreen] Получаем актуальные данные закупа ${widget.purchase.id}');
      final updatedPurchase = await _purchaseService.getPurchaseById(widget.purchase.id);
      if (updatedPurchase == null) {
        throw Exception('Не удалось получить актуальные данные закупа');
      }
      
      debugPrint('[PurchaseDetailScreen] Актуальные данные получены:');
      debugPrint('[PurchaseDetailScreen] Поставщик: ${updatedPurchase.supplierName}');
      debugPrint('[PurchaseDetailScreen] Количество товаров: ${updatedPurchase.items.length}');
      
      // Логируем детали каждого товара
      for (int i = 0; i < updatedPurchase.items.length; i++) {
        final item = updatedPurchase.items[i];
        debugPrint('[PurchaseDetailScreen] Товар $i: ${item.productName}');
        debugPrint('[PurchaseDetailScreen]   - Заказано: ${item.orderedQty}');
        debugPrint('[PurchaseDetailScreen]   - Принято: ${item.receivedQty}');
        debugPrint('[PurchaseDetailScreen]   - Недостача: ${item.missingQty}');
        debugPrint('[PurchaseDetailScreen]   - Статус: ${item.status} (${item.statusDisplayName})');
      }
      
      debugPrint('[PurchaseDetailScreen] Отправляем в API');
      
      // Вызываем API для оприходования с актуальными данными
      final success = await _satushiApiService.incomeRequest(
        updatedPurchase, 
        _currentUser!.satushiToken!
      );
      
      if (success) {
        // Если оприходование успешно, переводим на следующий этап
        debugPrint('[PurchaseDetailScreen] Оприходование успешно, обновляем статус закупа ${widget.purchase.id} на stocked');
        await _purchaseService.updatePurchaseStatus(widget.purchase.id, PurchaseStatus.stocked);
        debugPrint('[PurchaseDetailScreen] Статус закупа обновлен на stocked');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товары успешно оприходованы!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Возвращаемся назад с результатом для обновления списка
        if (mounted) {
          debugPrint('[PurchaseDetailScreen] Возвращаемся назад с результатом "stocked"');
          Navigator.pop(context, 'stocked');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка оприходования: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() { _stockingInProgress = false; });
    }
  }

  Future<void> _rejectProcurement() async {
    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить закуп'),
        content: Text('Вы уверены, что хотите вернуть закуп "${widget.purchase.supplierName}" на предыдущий этап?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отклонить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Определяем предыдущий статус в зависимости от текущего
        PurchaseStatus previousStatus;
        String statusMessage;
        
        switch (widget.purchase.status) {
          case PurchaseStatus.receiving:
            previousStatus = PurchaseStatus.created;
            statusMessage = 'Закуп возвращен в статус "Создан"';
            break;
          case PurchaseStatus.stocked:
            previousStatus = PurchaseStatus.receiving;
            statusMessage = 'Закуп возвращен в статус "Оприходывание"';
            break;
          case PurchaseStatus.inStock:
            previousStatus = PurchaseStatus.stocked;
            statusMessage = 'Закуп возвращен в статус "Принять на склад"';
            break;
          case PurchaseStatus.onSale:
            previousStatus = PurchaseStatus.inStock;
            statusMessage = 'Закуп возвращен в статус "Выставка на продажу"';
            break;
          default:
            // Для закупа в статусе "created" нельзя отклонить
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Закуп в статусе "Создан" нельзя отклонить'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
        }

        // Обновляем статус закупа
        await _purchaseService.updatePurchaseStatus(
          widget.purchase.id, 
          previousStatus
        );
        
        // Показываем уведомление об успехе
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusMessage),
              backgroundColor: Colors.green,
            ),
          );
          
          // Возвращаемся на предыдущий экран
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при отклонении закупа: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markShortageAsReceived(Shortage shortage) async {
    try {
      await _shortageService.markShortageAsReceived(
        shortage.id,
        userId: _currentUser?.uid,
        userName: _currentUser?.name ?? _currentUser?.email,
      );
      _loadShortages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостача отмечена как полученная')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _markShortageAsNotReceived(Shortage shortage) async {
    try {
      await _shortageService.markShortageAsNotReceived(
        shortage.id,
        userId: _currentUser?.uid,
        userName: _currentUser?.name ?? _currentUser?.email,
      );
      _loadShortages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостача отмечена как не полученная')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.purchase.dateCreated.toDate();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали закупа'),
        backgroundColor: Colors.white,
        elevation: 2,
        foregroundColor: Colors.black,
        actions: [
          // Кнопка отклонения для суперадмина
          if (_currentUser?.role == 'superadmin')
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.orange),
              tooltip: 'Отклонить закуп',
              onPressed: _rejectProcurement,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Основная информация о закупе
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.purchase.supplierName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Дата: ${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Статус: ${widget.purchase.statusDisplayName}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(widget.purchase.statusColor),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.green[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Итого: ${widget.purchase.totalAmount.toStringAsFixed(2)} ₸',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    if (widget.purchase.notes != null && widget.purchase.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Примечания: ${widget.purchase.notes}',
                              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Кнопки действий
            if (widget.purchase.status == PurchaseStatus.created)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoodsReceivingScreen(purchase: widget.purchase),
                      ),
                    );
                    if (result == true) {
                      _loadShortages();
                    }
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Приемка товаров'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            
            if (widget.purchase.status == PurchaseStatus.receiving)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _stockingInProgress ? null : _stockItems,
                  icon: _stockingInProgress 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.inventory),
                  label: Text(_stockingInProgress ? 'Оприходование...' : 'Оприходовать'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Позиции закупа
            const Text(
              'Позиции закупа',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.purchase.items.length,
              itemBuilder: (context, i) {
                final item = widget.purchase.items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Заказано: ${item.orderedQty} × ${item.purchasePrice.toStringAsFixed(2)} ₸ = ${item.totalPrice.toStringAsFixed(2)} ₸'),
                        if (item.receivedQty != null)
                          Text('Принято: ${item.receivedQty} шт.', style: const TextStyle(color: Colors.green)),
                        if (item.missingQty != null && item.missingQty! > 0)
                          Text('Недостача: ${item.missingQty} шт.', style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(item.statusColor),
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
            ),
            
            const SizedBox(height: 20),
            
            // Недостачи
            if (_shortages.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Недостачи',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _shortages.length,
                itemBuilder: (context, i) {
                  final shortage = _shortages[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        shortage.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Недостача: ${shortage.missingQty} шт.'),
                          Text('Статус: ${shortage.statusDisplayName}'),
                          if (shortage.notes != null && shortage.notes!.isNotEmpty)
                            Text('Примечания: ${shortage.notes}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(shortage.statusColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              shortage.statusDisplayName,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          if (shortage.status == ShortageStatus.waiting) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _markShortageAsReceived(shortage),
                              tooltip: 'Отметить как полученное',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _markShortageAsNotReceived(shortage),
                              tooltip: 'Отметить как не полученное',
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            
            if (_loadingShortages)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}


