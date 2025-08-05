import 'package:flutter/material.dart';
import 'invoice_list_screen.dart';
import 'outlet_screen.dart';
import '../services/auth_service.dart';
import 'warehouse_screen.dart';
import 'admin_packing_invoices_screen.dart';
import 'admin_delivery_invoices_screen.dart';
import 'admin_incoming_invoices_screen.dart';
import 'admin_delivered_invoices_screen.dart';
import 'sales_rep_profile_screen.dart';

class SalesHomeScreen extends StatefulWidget {
  const SalesHomeScreen({Key? key}) : super(key: key);

  @override
  State<SalesHomeScreen> createState() => _SalesHomeScreenState();
}

class _SalesHomeScreenState extends State<SalesHomeScreen> {
  int _selectedIndex = 0;

  Widget _buildInvoicesTab(BuildContext context) {
    final sections = [
      {'emoji': '🍦', 'label': 'На рассмотрении', 'screen': AdminIncomingInvoicesScreen(forSales: true)},
      {'emoji': '🔨', 'label': 'На сборке', 'screen': AdminPackingInvoicesScreen(forSales: true)},
      {'emoji': '🚚', 'label': 'Передан на доставку', 'screen': AdminDeliveryInvoicesScreen(forSales: true)},
      {'emoji': '✅', 'label': 'Доставлен', 'screen': AdminDeliveredInvoicesScreen(forSales: true)},
      {'emoji': '📦', 'label': 'Архив накладных', 'screen': InvoiceListScreen()}, // Используем общий экран с фильтрацией по sales
    ];
    return Stack(
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => s['screen'] as Widget),
                  );
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
    );
  }

  static final List<Widget> _tabBodies = [
    // 0: Накладные (основная сетка)
    // _buildInvoicesTab будет вызываться напрямую
    SizedBox.shrink(),
    OutletScreen(),
    WarehouseScreen(),
    SalesRepProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: const Text('Мои накладные', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
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
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _selectedIndex == 0 ? _buildInvoicesTab(context) : _tabBodies[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: const Color(0xFF7B61FF),
        unselectedItemColor: Colors.grey,
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
            icon: Icon(Icons.inventory_2),
            label: 'Склад',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
} 