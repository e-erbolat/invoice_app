import 'package:flutter/material.dart';
import 'purchase_create_screen.dart';
import '../services/procurement_service.dart';
import '../models/procurement.dart';
import 'purchase_detail_screen.dart';

class ProductProcurementScreen extends StatefulWidget {
  const ProductProcurementScreen({Key? key}) : super(key: key);

  @override
  State<ProductProcurementScreen> createState() => _ProductProcurementScreenState();
}

class _ProductProcurementScreenState extends State<ProductProcurementScreen> {
  final ProcurementService _procurementService = ProcurementService();
  bool _loading = true;
  List<Procurement> _purchases = [];
  List<Procurement> _arrivals = [];
  List<Procurement> _shortages = [];
  List<Procurement> _forSales = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<List<Procurement>>([
        _procurementService.getProcurementsByStatus(ProcurementStatus.purchase),
        _procurementService.getProcurementsByStatus(ProcurementStatus.arrival),
        _procurementService.getProcurementsByStatus(ProcurementStatus.shortage),
        _procurementService.getProcurementsByStatus(ProcurementStatus.forSale),
      ]);
      if (!mounted) return;
      setState(() {
        _purchases = results[0];
        _arrivals = results[1];
        _shortages = results[2];
        _forSales = results[3];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _acceptToArrival(Procurement p) async {
    await _procurementService.updateProcurementStatus(p.id, ProcurementStatus.arrival);
    _load();
  }

  Future<void> _moveToShortage(Procurement p) async {
    await _procurementService.updateProcurementStatus(p.id, ProcurementStatus.shortage);
    _load();
  }

  Future<void> _moveToForSale(Procurement p) async {
    await _procurementService.updateProcurementStatus(p.id, ProcurementStatus.forSale);
    _load();
  }

  Widget _buildCard(Procurement p, {List<Widget> trailingActions = const []}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.shopping_bag, color: Colors.blue),
        title: Text(p.sourceName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Дата: ${p.date.toDate().day.toString().padLeft(2,'0')}.${p.date.toDate().month.toString().padLeft(2,'0')}.${p.date.toDate().year}  •  Итого: ${p.totalAmount.toStringAsFixed(2)} ₸',
        ),
        trailing: trailingActions.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: trailingActions,
              ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PurchaseDetailScreen(procurement: p)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Закуп товара'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Закуп товара'),
              Tab(text: 'Приход товара'),
              Tab(text: 'Недостача'),
              Tab(text: 'Выставка на продажу'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchaseCreateScreen()),
            );
            _load();
          },
          child: const Icon(Icons.add),
          tooltip: 'Создать закуп',
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Ошибка загрузки: \n\n$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Повторить')),
                      ],
                    ),
                  )
                : TabBarView(
                children: [
                  // Закуп товара
                  _purchases.isEmpty
                      ? const Center(child: Text('Закупы отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _purchases.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _purchases[i];
                            return _buildCard(p, trailingActions: [
                              ElevatedButton(onPressed: () => _acceptToArrival(p), child: const Text('Принять')),
                            ]);
                          },
                        ),
                  // Приход товара
                  _arrivals.isEmpty
                      ? const Center(child: Text('Приходы отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _arrivals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _arrivals[i];
                            return _buildCard(p, trailingActions: [
                              OutlinedButton(onPressed: () => _moveToShortage(p), child: const Text('Недостача')),
                              const SizedBox(width: 8),
                              ElevatedButton(onPressed: () => _moveToForSale(p), child: const Text('Выставка')),
                            ]);
                          },
                        ),
                  // Недостача
                  _shortages.isEmpty
                      ? const Center(child: Text('Недостачи отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _shortages.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _shortages[i];
                            return _buildCard(p, trailingActions: [
                              ElevatedButton(onPressed: () => _moveToForSale(p), child: const Text('Выставка')),
                            ]);
                          },
                        ),
                  // Выставка на продажу
                  _forSales.isEmpty
                      ? const Center(child: Text('Пусто'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _forSales.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _forSales[i];
                            return _buildCard(p);
                          },
                        ),
                ],
              ),
      ),
    );
  }
}

class _ProcItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ProcItem({required this.icon, required this.title, required this.subtitle});
}


