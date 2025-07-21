import "package:flutter/material.dart";

class HomeScreen extends StatelessWidget {
  final List<Map<String, dynamic>> orders = [
    {
      "point": "Магазин А",
      "sum": 12000,
      "date": "2025-07-10",
    },
    {
      "point": "Магазин B",
      "sum": 15400,
      "date": "2025-07-09",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Мои накладные")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.shopping_bag),
                  label: Text("Каталог товаров"),
                  onPressed: () {
                    Navigator.pushNamed(context, "/products");
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.people),
                  label: Text("Представители"),
                  onPressed: () {
                    Navigator.pushNamed(context, "/reps");
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.store),
                  label: Text("Торговые точки"),
                  onPressed: () {
                    Navigator.pushNamed(context, "/outlets");
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.bar_chart),
                  label: Text("Отчёт по точкам"),
                  onPressed: () {
                    Navigator.pushNamed(context, "/outlet_report");
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.leaderboard),
                  label: Text("Отчёт по представителям"),
                  onPressed: () {
                    Navigator.pushNamed(context, "/sales_rep_report");
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.receipt_long),
                  label: Text("Все накладные"),
                  onPressed: () {
                    Navigator.pushNamed(context, "/invoices");
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(orders[i]["point"]),
                subtitle: Text("Сумма: \$${orders[i]["sum"]}"),
                trailing: Text(orders[i]["date"]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.pushNamed(context, "/create_invoice");
        },
      ),
    );
  }
}
