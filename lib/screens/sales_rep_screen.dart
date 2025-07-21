import 'package:flutter/material.dart';
import '../models/sales_rep.dart';
import '../services/firebase_service.dart';

class SalesRepScreen extends StatefulWidget {
  @override
  _SalesRepScreenState createState() => _SalesRepScreenState();
}

class _SalesRepScreenState extends State<SalesRepScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<SalesRep> _salesReps = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSalesReps();
  }

  Future<void> _loadSalesReps() async {
    setState(() {
      _isLoading = true;
    });
    
    final salesReps = await _firebaseService.getSalesReps();
    setState(() {
      _salesReps = salesReps;
      _isLoading = false;
    });
  }

  List<SalesRep> get _filteredSalesReps {
    if (_searchQuery.isEmpty) {
      return _salesReps;
    }
    return _salesReps.where((rep) =>
        rep.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        rep.region.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        rep.email.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void _showAddEditDialog([SalesRep? salesRep]) {
    final nameController = TextEditingController(text: salesRep?.name ?? '');
    final phoneController = TextEditingController(text: salesRep?.phone ?? '');
    final emailController = TextEditingController(text: salesRep?.email ?? '');
    final regionController = TextEditingController(text: salesRep?.region ?? '');
    final commissionController = TextEditingController(text: salesRep?.commissionRate.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(salesRep == null ? 'Добавить представителя' : 'Редактировать представителя'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'ФИО'),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Телефон'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: regionController,
                decoration: InputDecoration(labelText: 'Регион'),
              ),
              TextField(
                controller: commissionController,
                decoration: InputDecoration(labelText: 'Комиссия (%)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newSalesRep = SalesRep(
                id: salesRep?.id ?? '',
                name: nameController.text,
                phone: phoneController.text,
                email: emailController.text,
                region: regionController.text,
                commissionRate: double.tryParse(commissionController.text) ?? 0.0,
                createdAt: salesRep?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

                      if (salesRep == null) {
          await _firebaseService.addSalesRep(newSalesRep);
        } else {
          await _firebaseService.updateSalesRep(newSalesRep);
        }

              Navigator.pop(context);
              _loadSalesReps();
            },
            child: Text(salesRep == null ? 'Добавить' : 'Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(SalesRep salesRep) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить представителя'),
        content: Text('Вы уверены, что хотите удалить представителя "${salesRep.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firebaseService.deleteSalesRep(salesRep.id);
              Navigator.pop(context);
              _loadSalesReps();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Поиск представителей',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Обновить',
                onPressed: _loadSalesReps,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _filteredSalesReps.length,
                  itemBuilder: (context, i) {
                    final rep = _filteredSalesReps[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(rep.name.isNotEmpty ? rep.name[0] : '?')),
                        title: Text(rep.name),
                        subtitle: Text('Телефон: ${rep.phone}\nEmail: ${rep.email}\nРегион: ${rep.region}\nКомиссия: ${rep.commissionRate.toStringAsFixed(1)}%'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showAddEditDialog(rep);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Редактировать'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
} 