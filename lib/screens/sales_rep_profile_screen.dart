import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_rep.dart';
import '../services/auth_service.dart';

class SalesRepProfileScreen extends StatefulWidget {
  @override
  _SalesRepProfileScreenState createState() => _SalesRepProfileScreenState();
}

class _SalesRepProfileScreenState extends State<SalesRepProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _regionController = TextEditingController();
  final _commissionController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  SalesRep? _salesRep;

  @override
  void initState() {
    super.initState();
    _loadSalesRepData();
  }

  Future<void> _loadSalesRepData() async {
    try {
      final currentUser = await AuthService().getCurrentUser();
      if (currentUser?.salesRepId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('sales_reps')
            .doc(currentUser!.salesRepId)
            .get();
        
        if (doc.exists) {
          _salesRep = SalesRep.fromMap(doc.data()!);
          _nameController.text = _salesRep!.name;
          _phoneController.text = _salesRep!.phone;
          _regionController.text = _salesRep!.region;
          _commissionController.text = _salesRep!.commissionRate.toString();
          setState(() {});
        }
      }
    } catch (e) {
      print('Ошибка загрузки данных: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUser = await AuthService().getCurrentUser();
      if (currentUser?.salesRepId != null) {
        final updatedData = {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'region': _regionController.text.trim(),
          'commissionRate': double.tryParse(_commissionController.text) ?? 0.0,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await FirebaseFirestore.instance
            .collection('sales_reps')
            .doc(currentUser!.salesRepId)
            .update(updatedData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Профиль обновлен!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка сохранения: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Профиль торгового представителя'),
        actions: [
          if (_salesRep != null)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _isLoading ? null : _saveProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Имя представителя',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите имя';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Телефон',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите телефон';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              TextFormField(
                controller: _regionController,
                decoration: InputDecoration(
                  labelText: 'Регион',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите регион';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              TextFormField(
                controller: _commissionController,
                decoration: InputDecoration(
                  labelText: 'Комиссия (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите комиссию';
                  }
                  final commission = double.tryParse(value);
                  if (commission == null || commission < 0 || commission > 100) {
                    return 'Комиссия должна быть от 0 до 100%';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              
              if (_salesRep != null) ...[
                Text(
                  'Информация о профиле:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('ID: ${_salesRep!.id}'),
                Text('Email: ${_salesRep!.email}'),
                Text('Создан: ${_salesRep!.createdAt.toString().split('.')[0]}'),
                SizedBox(height: 16),
              ],
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Сохранить профиль'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _regionController.dispose();
    _commissionController.dispose();
    super.dispose();
  }
} 