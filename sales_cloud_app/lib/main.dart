import "package:flutter/material.dart";
import "screens/home_screen.dart";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Накладные",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
      routes: {
        "/products": (_) => ProductCatalogScreen(),
        "/reps": (_) => SalesRepScreen(),
        "/outlets": (_) => OutletScreen(),
        "/create_invoice": (_) => InvoiceCreateScreen(),
        "/invoices": (_) => InvoiceListScreen(),
        "/outlet_report": (_) => OutletReportScreen(),
        "/sales_rep_report": (_) => SalesRepReportScreen(),
      },
    );
  }
}

class ProductCatalogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Каталог товаров")),
      body: Center(child: Text("Каталог товаров - в разработке")),
    );
  }
}

class SalesRepScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Торговые представители")),
      body: Center(child: Text("Торговые представители - в разработке")),
    );
  }
}

class OutletScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Торговые точки")),
      body: Center(child: Text("Торговые точки - в разработке")),
    );
  }
}

class InvoiceCreateScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Создать накладную")),
      body: Center(child: Text("Создание накладной - в разработке")),
    );
  }
}

class InvoiceListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Все накладные")),
      body: Center(child: Text("Список накладных - в разработке")),
    );
  }
}

class OutletReportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Отчёт по торговым точкам")),
      body: Center(child: Text("Отчёт по точкам - в разработке")),
    );
  }
}

class SalesRepReportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Отчёт по представителям")),
      body: Center(child: Text("Отчёт по представителям - в разработке")),
    );
  }
}
