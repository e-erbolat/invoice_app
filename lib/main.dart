import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/product_catalog_screen.dart';
import 'screens/sales_rep_screen.dart';
import 'screens/outlet_screen.dart';
import 'screens/invoice_create_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/invoice_list_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'models/app_user.dart';
import 'screens/outlet_report_screen.dart';
import 'screens/sales_rep_report_screen.dart';
import 'screens/admin_incoming_invoices_screen.dart';
import 'screens/admin_packing_invoices_screen.dart';
import 'screens/admin_delivery_invoices_screen.dart';
import 'screens/admin_delivered_invoices_screen.dart';
import 'screens/sales_home_screen.dart';
import 'screens/admin_payment_check_invoices_screen.dart';
import 'screens/cash_register_screen.dart';
import 'screens/cash_expense_create_screen.dart';
import 'screens/cash_expenses_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Накладные',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthGate(),
      routes: {
        '/products': (_) => ProductCatalogScreen(),
        '/reps': (_) => SalesRepScreen(),
        '/outlets': (_) => OutletScreen(),
        '/create_invoice': (_) => const InvoiceCreateScreen(),
        '/login': (_) => LoginScreen(),
        '/register': (_) => RegisterScreen(),
        '/invoice_list': (_) => const InvoiceListScreen(),
        '/admin_incoming_invoices': (_) => const AdminIncomingInvoicesScreen(),
        '/admin_packing_invoices': (_) => const AdminPackingInvoicesScreen(),
        '/admin_delivery_invoices': (_) => const AdminDeliveryInvoicesScreen(),
        '/admin_delivered_invoices': (context) => AdminDeliveredInvoicesScreen(),
        '/outlet_report': (_) => const OutletReportScreen(),
        '/sales_rep_report': (_) => const SalesRepReportScreen(),
        '/admin_payment_check_invoices': (_) => const AdminPaymentCheckInvoicesScreen(),
        '/cash_register': (_) => const CashRegisterScreen(),
        '/cash_expense_create': (_) => const CashExpenseCreateScreen(),
        '/cash_expenses': (_) => const CashExpensesScreen(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      debugPrint('[AuthGate] Проверка текущей сессии...');
      final user = await AuthService().getCurrentUser();
      if (user != null) {
        debugPrint('[AuthGate] Пользователь найден: email=${user.email}, role=${user.role}');
      } else {
        debugPrint('[AuthGate] Пользователь не найден, требуется авторизация');
      }
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AuthGate] Ошибка при проверке сессии: $e');
      setState(() {
        _user = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_user == null) {
      return LoginScreen();
    }
    if (_user!.role == 'admin' || _user!.role == 'superadmin') {
      return const HomeScreen();
    } else {
      return const SalesHomeScreen();
    }
  }
}





class OutletReportScreen extends StatelessWidget {
  const OutletReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Отчёт по торговым точкам')),
      body: Center(child: Text('Отчёт по точкам - в разработке')),
    );
  }
}

class SalesRepReportScreen extends StatelessWidget {
  const SalesRepReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Отчёт по представителям')),
      body: Center(child: Text('Отчёт по представителям - в разработке')),
    );
  }
} 