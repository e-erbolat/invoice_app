import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'outlet_screen.dart';
import 'admin_delivered_invoices_screen.dart';
import 'sales_rep_screen.dart';
import 'warehouse_screen.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../models/product.dart';
import '../services/cash_register_service.dart';
import '../services/invoice_service.dart';
import '../models/invoice.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import '../services/purchase_service.dart';
import '../services/shortage_service.dart';
import '../models/purchase.dart';
import '../models/shortage.dart';

// Если есть отдельный экран профиля, импортируйте его, иначе будет заглушка

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppUser? _user;
  bool _loading = true;
  int _selectedIndex = 0; // Добавлено для bottom navigation
  double _totalCashAmount = 0.0;
  final CashRegisterService _cashRegisterService = CashRegisterService();
  final InvoiceService _invoiceService = InvoiceService();
  final PurchaseService _purchaseService = PurchaseService();
  final ShortageService _shortageService = ShortageService();

  // Счетчики для бейджей
  int _countReview = 0;
  int _countPacking = 0;
  int _countDelivery = 0;
  int _countDelivered = 0;
  int _countPayment = 0;
  int _activeProcurementsCount = 0;

  List<Widget> get _tabBodies => [
    _InvoicesTab(user: _user),
    OutletScreen(),
    SalesRepScreen(),
    WarehouseScreen(),
    AnalyticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCashAmount();
    _loadInvoiceCounters();
    _loadActiveProcurementsCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем сумму кассы при возврате на экран для админа и суперадмина
    if (_user?.role == 'admin' || _user?.role == 'superadmin') {
      _loadCashAmount();
    }
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getCurrentUser();
    if (mounted) {
      setState(() {
        _user = user;
        _loading = false;
      });
      print('[HomeScreen] Пользователь загружен: email=${user?.email}, role=${user?.role}');
      // Загружаем сумму кассы после загрузки пользователя
      if (user?.role == 'admin' || user?.role == 'superadmin') {
        print('[HomeScreen] Пользователь ${user?.role}, загружаем кассу');
        _loadCashAmount();
      } else {
        print('[HomeScreen] Пользователь не админ/суперадмин, касса не загружается');
      }
    }
  }

  Future<void> _loadCashAmount() async {
    // Загружаем сумму кассы для админа и суперадмина
    if (_user?.role != 'admin' && _user?.role != 'superadmin') {
      print('[HomeScreen] Касса не загружается: роль пользователя = ${_user?.role}');
      return;
    }
    
    print('[HomeScreen] Загружаем кассу для ${_user?.role}');
    try {
      final amount = await _cashRegisterService.getTotalCashAmount();
      if (mounted) {
        setState(() {
          _totalCashAmount = amount;
        });
        print('[HomeScreen] Касса загружена: ${_totalCashAmount.toStringAsFixed(2)} ₸');
      }
    } catch (e) {
      print('[HomeScreen] Ошибка при загрузке суммы кассы: $e');
    }
  }

  Future<void> _loadInvoiceCounters() async {
    try {
      final results = await Future.wait<int>([
        _invoiceService.getInvoiceCountByStatus(InvoiceStatus.review),
        _invoiceService.getInvoiceCountByStatus(InvoiceStatus.packing),
        _invoiceService.getInvoiceCountByStatus(InvoiceStatus.delivery),
        _invoiceService.getInvoiceCountByStatus(InvoiceStatus.delivered),
        _invoiceService.getInvoiceCountByStatus(InvoiceStatus.paymentChecked),
      ]);
      if (!mounted) return;
      setState(() {
        _countReview = results[0];
        _countPacking = results[1];
        _countDelivery = results[2];
        _countDelivered = results[3];
        _countPayment = results[4];
      });
    } catch (e) {
      // проглатываем ошибку, бейджи необязательны
    }
  }

  Future<void> _loadActiveProcurementsCount() async {
    try {
      // Получаем все закупы
      final purchases = await _purchaseService.getAllPurchases();
      
      // Подсчитываем активные закупы (не в архиве)
      final activePurchases = purchases.where((p) => 
        p.status != PurchaseStatus.completed && 
        p.status != PurchaseStatus.closedWithShortage
      ).length;
      
      // Получаем все недостачи
      final shortages = await _shortageService.getAllShortages();
      
      // Подсчитываем активные недостачи (не завершенные)
      final activeShortages = shortages.where((s) => 
        s.status != ShortageStatus.completed
      ).length;
      
      if (mounted) {
        setState(() {
          _activeProcurementsCount = activePurchases + activeShortages;
        });
      }
    } catch (e) {
      print('[HomeScreen] Ошибка загрузки счетчика активных закупов: $e');
    }
  }

  Widget _buildAdminInvoicesTab(BuildContext context) {
    final isAdmin = _user?.role == 'admin' || _user?.role == 'superadmin';
    final sections = [
      if (isAdmin) ...[
        {'emoji': '🍦', 'label': 'Входящие накладные', 'route': '/admin_incoming_invoices', 'count': _countReview},
        {'emoji': '🔨', 'label': 'На сборке', 'route': '/admin_packing_invoices', 'count': _countPacking},
        {'emoji': '🚚', 'label': 'Передан на доставку', 'route': '/admin_delivery_invoices', 'count': _countDelivery},
        {'emoji': '✅', 'label': 'Получение оплат', 'route': '/admin_delivered_invoices', 'count': _countDelivered},
        {'emoji': '✔️', 'label': 'Проверка оплат', 'route': '/admin_payment_check_invoices', 'count': _countPayment},
        {'emoji': '📦', 'label': 'Архив накладных', 'route': '/invoice_list'},
        if (_user?.role == 'admin' || _user?.role == 'superadmin')
          {'emoji': '💰', 'label': 'Касса', 'route': '/cash_register'},
        if (_user?.role == 'admin' || _user?.role == 'superadmin')
          {'emoji': '💸', 'label': 'Расходы', 'route': '/cash_expenses'},
        {'emoji': '🛍️', 'label': 'Активные закупы', 'route': '/active_procurements', 'count': _activeProcurementsCount},
        {'emoji': '📚', 'label': 'Каталог товаров', 'route': '/products', 'count': _activeProcurementsCount > 0 ? _activeProcurementsCount : null},
        {'emoji': '📊', 'label': 'Анализ работы торговых', 'route': '/sales_analysis'},
      ]
    ];
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                itemCount: sections.length,
                itemBuilder: (context, i) {
                  final s = sections[i];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: Text(s['emoji'] as String, style: const TextStyle(fontSize: 28)),
                      title: Text(s['label'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((s['count'] as int?) != null && (s['count'] as int) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (s['count'] as int).toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, s['route'] as String).then((_) {
                          // Обновляем кассу после возврата с экрана кассы
                          if (s['route'] == '/cash_register' && (_user?.role == 'admin' || _user?.role == 'superadmin')) {
                            _loadCashAmount();
                          }
                          // Обновляем бейджи при возврате
                          _loadInvoiceCounters();
                          _loadActiveProcurementsCount();
                        });
                      },
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 32,
                right: 16,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF7B61FF),
                  onPressed: () {
                    Navigator.pushNamed(context, '/create_invoice');
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Создать накладную',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Удалить метод _showParseDialog полностью

  @override
  Widget build(BuildContext context) {
    print('[HomeScreen] build: _user.email=${_user?.email}, _user.role=${_user?.role}');
    print('[HomeScreen] build: _totalCashAmount=${_totalCashAmount.toStringAsFixed(2)} ₸');
    print('[HomeScreen] build: показывать кассу = ${_user?.role == 'admin' || _user?.role == 'superadmin'}');
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Загрузка...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    String appBarTitle;
    if (_user?.role == 'admin' || _user?.role == 'superadmin') {
      // Для админов
      appBarTitle = 'Мои накладные';
      if (_selectedIndex == 1) appBarTitle = 'Торговые точки';
      if (_selectedIndex == 2) appBarTitle = 'Торговые представители';
      if (_selectedIndex == 3) appBarTitle = 'Каталоги';
      if (_selectedIndex == 4) appBarTitle = 'Аналитика';
    } else {
      // Для торговых представителей
      appBarTitle = 'Мои накладные';
      if (_selectedIndex == 1) appBarTitle = 'Торговые точки';
      if (_selectedIndex == 2) appBarTitle = 'Торговые представители';
      if (_selectedIndex == 3) appBarTitle = 'Каталоги';
      if (_selectedIndex == 4) appBarTitle = 'Аналитика';
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFCF8FF),
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if ((_user?.role == 'admin' || _user?.role == 'superadmin') && _selectedIndex != 4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Касса: ${_totalCashAmount.toStringAsFixed(2)} ₸',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loadCashAmount,
                    child: Icon(
                      Icons.refresh,
                      color: Colors.green,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          // Кнопка профиля для всех вкладок
          IconButton(
            icon: const Icon(Icons.person, color: Colors.black),
            onPressed: () async {
              final user = await AuthService().getCurrentUser();
              if (user == null) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => ProfileSettingsSheet(user: user),
              );
            },
            tooltip: 'Профиль',
          ),

          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              await AuthService().signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? _buildAdminInvoicesTab(context)
          : _tabBodies[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Обновляем кассу при переключении на вкладку накладных для админа и суперадмина
          if (index == 0 && (_user?.role == 'admin' || _user?.role == 'superadmin')) {
            _loadCashAmount();
          }
        },
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Накладные',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Клиенты',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_alt),
            label: 'Торговые',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.inventory_2),
                if (_activeProcurementsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _activeProcurementsCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Каталог',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Аналитика',
          ),
        ],
      ),
      floatingActionButton: null, // FAB уже встроен в Stack
    );
  }
}

// Вынес сетку накладных в отдельный виджет для удобства
class _InvoicesTab extends StatelessWidget {
  final AppUser? user;
  const _InvoicesTab({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAdmin = user?.role == 'admin' || user?.role == 'superadmin';
    final List<_InvoiceSection> sections = [
      if (isAdmin) ...[
        _InvoiceSection(
          icon: Icons.inbox,
          label: 'Входящие накладные',
          route: '/admin_incoming_invoices',
        ),
        _InvoiceSection(
          icon: Icons.build,
          label: 'На сборке',
          route: '/admin_packing_invoices',
        ),
        _InvoiceSection(
          icon: Icons.local_shipping,
          label: 'Передан на доставку',
          route: '/admin_delivery_invoices',
        ),
        _InvoiceSection(
          icon: Icons.done_all,
          label: 'Доставлен',
          route: '/admin_delivered_invoices',
        ),
        _InvoiceSection(
          icon: Icons.verified,
          label: 'Проверка оплат',
          route: '/admin_payment_check_invoices',
        ),
        _InvoiceSection(
          icon: Icons.archive,
          label: 'Архив накладных',
          route: '/invoice_list',
        ),
      ]
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final section = sections[i];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: Icon(section.icon, size: 32, color: Colors.deepPurple),
            title: Text(section.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, section.route);
            },
          ),
        );
      },
    );
  }
}

class _InvoiceSection {
  final IconData icon;
  final String label;
  final String route;
  const _InvoiceSection({required this.icon, required this.label, required this.route});
} 