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

  List<Widget> get _tabBodies => [
    _InvoicesTab(user: _user),
    OutletScreen(),
    SalesRepScreen(),
    WarehouseScreen(),
    Center(child: Text('Профиль', style: TextStyle(fontSize: 24))),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCashAmount();
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

  Widget _buildAdminInvoicesTab(BuildContext context) {
    final isAdmin = _user?.role == 'admin' || _user?.role == 'superadmin';
    final sections = [
      if (isAdmin) ...[
        {'emoji': '🍦', 'label': 'Входящие накладные', 'route': '/admin_incoming_invoices'},
        {'emoji': '🔨', 'label': 'На сборке', 'route': '/admin_packing_invoices'},
        {'emoji': '🚚', 'label': 'Передан на доставку', 'route': '/admin_delivery_invoices'},
        {'emoji': '✅', 'label': 'Доставлен', 'route': '/admin_delivered_invoices'},
        {'emoji': '✔️', 'label': 'Проверка оплат', 'route': '/admin_payment_check_invoices'},
        {'emoji': '📦', 'label': 'Архив накладных', 'route': '/invoice_list'},
        if (_user?.role == 'admin' || _user?.role == 'superadmin')
          {'emoji': '💰', 'label': 'Касса', 'route': '/cash_register'},
        if (_user?.role == 'admin' || _user?.role == 'superadmin')
          {'emoji': '💸', 'label': 'Расходы', 'route': '/cash_expenses'},
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
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(context, s['route'] as String).then((_) {
                          // Обновляем кассу после возврата с экрана кассы
                          if (s['route'] == '/cash_register' && (_user?.role == 'admin' || _user?.role == 'superadmin')) {
                            _loadCashAmount();
                          }
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
        appBar: AppBar(title: const Text("Мои накладные")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isAdmin = _user?.role == 'admin' || _user?.role == 'superadmin';
    final items = [
      if (isAdmin)
        {'icon': Icons.inbox, 'label': 'Входящие накладные', 'route': '/admin_incoming_invoices'},
      if (isAdmin)
        {'icon': Icons.build, 'label': 'На сборке', 'route': '/admin_packing_invoices'},
      if (isAdmin)
        {'icon': Icons.local_shipping, 'label': 'На доставке', 'route': '/admin_delivery_invoices'},
      if (isAdmin)
        {'icon': Icons.done_all, 'label': 'Доставлен', 'route': '/admin_delivered_invoices'},
      if (isAdmin)
        {'icon': Icons.verified, 'label': 'Проверка оплат', 'route': '/admin_payment_check_invoices'},
      if (isAdmin)
        {'icon': Icons.archive, 'label': 'Архив накладных', 'route': '/invoice_list'},
      if (isAdmin)
        {'icon': Icons.inventory_2, 'label': 'Каталог товаров', 'route': '/products'},
      if (isAdmin)
        {'icon': Icons.location_city, 'label': 'Отчёт по точкам', 'route': '/outlet_report'},
      if (isAdmin)
        {'icon': Icons.people_alt, 'label': 'Отчёт по представителям', 'route': '/sales_rep_report'},
      {'icon': Icons.storefront, 'label': 'Торговые точки', 'route': '/outlets'},
      {'icon': Icons.add_box, 'label': 'Создать накладную', 'route': '/create_invoice'},
    ];

    String appBarTitle = 'Мои накладные';
    if (_selectedIndex == 1) appBarTitle = 'Торговые точки';
    if (_selectedIndex == 2) appBarTitle = 'Торговые представители';
    if (_selectedIndex == 3) appBarTitle = 'Каталоги';
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
          if (_user?.role == 'admin' || _user?.role == 'superadmin')
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Накладные',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Клиенты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt),
            label: 'Торговые',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Каталог',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
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