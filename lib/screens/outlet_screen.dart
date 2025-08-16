import 'package:flutter/material.dart';
import '../models/outlet.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import '../models/sales_rep.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/geocoding_service.dart';

class OutletScreen extends StatefulWidget {
  @override
  _OutletScreenState createState() => _OutletScreenState();
}

class _OutletScreenState extends State<OutletScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  List<Outlet> _outlets = [];
  List<SalesRep> _salesReps = [];
  bool _isLoading = true;
  String _searchQuery = '';

  String _sortField = 'name';
  final Map<String, String> _sortOptions = {
    'name': 'Имя',
    'address': 'Адрес',
    'phone': 'Телефон',
  };

  @override
  void initState() {
    super.initState();
    _loadUserAndOutlets();
  }

  Future<void> _loadUserAndOutlets() async {
    setState(() {
      _isLoading = true;
    });
    final user = await _authService.getCurrentUser();
    final outlets = await _firebaseService.getOutlets();
    final salesReps = await _firebaseService.getSalesReps();
    setState(() {
      _currentUser = user;
      _outlets = outlets;
      _salesReps = salesReps;
      _isLoading = false;
    });
  }

  List<Outlet> get _filteredOutlets {
    List<Outlet> filtered = _searchQuery.isEmpty
        ? _outlets
        : _outlets.where((outlet) =>
            outlet.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (outlet.region?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            outlet.contactPerson.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
    // Сортировка по выбранному полю
    filtered.sort((a, b) {
      final aValue = _sortField == 'name'
          ? a.name
          : _sortField == 'address'
              ? a.address
              : a.phone;
      final bValue = _sortField == 'name'
          ? b.name
          : _sortField == 'address'
              ? b.address
              : b.phone;
      return aValue.toLowerCase().compareTo(bValue.toLowerCase());
    });
    return filtered;
  }

  void _showAddEditDialog([Outlet? outlet]) {
    final nameController = TextEditingController(text: outlet?.name ?? '');
    final addressController = TextEditingController(text: outlet?.address ?? '');
    final phoneController = TextEditingController(text: outlet?.phone ?? '');
    final contactController = TextEditingController(text: outlet?.contactPerson ?? '');
    final regionController = TextEditingController(text: outlet?.region ?? '');
    final latController = TextEditingController(text: outlet?.latitude?.toString() ?? '');
    final lngController = TextEditingController(text: outlet?.longitude?.toString() ?? '');
    final geocoding = GeocodingService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(outlet == null ? 'Добавить торговую точку' : 'Редактировать торговую точку'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Адрес'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Телефон'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: 'Контакт'),
              ),
              TextField(
                controller: regionController,
                decoration: const InputDecoration(
                  labelText: 'Регион (необязательно)',
                  hintText: 'Оставьте пустым, если не нужно',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child:               TextField(
                controller: latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '50.123456',
                ),
              ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: '57.123456',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final addr = addressController.text.trim().isNotEmpty
                            ? addressController.text.trim()
                            : nameController.text.trim();
                        if (addr.isEmpty) return;
                        final res = await geocoding.geocodeAddress(addr);
                        if (res != null) {
                          latController.text = res.latitude.toStringAsFixed(6);
                          lngController.text = res.longitude.toStringAsFixed(6);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Координаты заполнены')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Не удалось определить координаты')),
                          );
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Определить по адресу'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final query = Uri.encodeComponent(addressController.text.isNotEmpty ? addressController.text : nameController.text);
                        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                        launchUrl(url);
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Открыть карту'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newOutlet = Outlet(
                id: outlet?.id ?? '',
                name: nameController.text.trim(),
                address: addressController.text.trim(),
                phone: phoneController.text.trim(),
                contactPerson: contactController.text.trim(),
                region: regionController.text.trim().isEmpty ? null : regionController.text.trim(),
                creatorId: _currentUser?.uid ?? '',
                creatorName: _currentUser?.email ?? '',
                createdAt: outlet?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
                latitude: double.tryParse(latController.text.replaceAll(',', '.')),
                longitude: double.tryParse(lngController.text.replaceAll(',', '.')),
              );
              if (outlet == null) {
                await _firebaseService.addOutlet(newOutlet);
              } else {
                await _firebaseService.updateOutlet(newOutlet);
              }
              if (mounted) {
                Navigator.pop(context);
                _loadUserAndOutlets();
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Outlet outlet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить торговую точку'),
        content: Text('Вы уверены, что хотите удалить торговую точку "${outlet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firebaseService.deleteOutlet(outlet.id);
              Navigator.pop(context);
              _loadUserAndOutlets();
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
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Поиск торговых точек',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortField,
                  items: _sortOptions.entries
                      .map((e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortField = value;
                      });
                    }
                  },
                  underline: Container(),
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  icon: const Icon(Icons.sort),
                  hint: const Text('Сортировка'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Обновить',
                  onPressed: _loadUserAndOutlets,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredOutlets.length,
                    itemBuilder: (context, index) {
                      final outlet = _filteredOutlets[index];
                      // Проверяем, заполнены ли контакты
                      final hasContacts = outlet.contactPerson.isNotEmpty && outlet.phone.isNotEmpty;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        color: hasContacts ? null : Colors.yellow.shade100, // Желтый фон если нет контактов
                        child: ListTile(
                          leading: Icon(
                            Icons.store, 
                            color: hasContacts ? Colors.deepPurple : Colors.orange, // Оранжевая иконка если нет контактов
                          ),
                          title: Text(
                            outlet.name,
                            style: TextStyle(
                              color: hasContacts ? null : Colors.orange.shade800, // Оранжевый текст если нет контактов
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Адрес: ${outlet.address}\n'
                                'Телефон: ${outlet.phone}\n'
                                'Контакт: ${outlet.contactPerson}\n'
                                '${outlet.region != null && outlet.region!.isNotEmpty ? 'Регион: ${outlet.region}\n' : ''}'
                                '${outlet.latitude != null && outlet.longitude != null ? 'Координаты: ${outlet.latitude!.toStringAsFixed(6)}, ${outlet.longitude!.toStringAsFixed(6)}' : 'Координаты: не указаны'}'
                              ),
                              if (!hasContacts) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.shade400),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning, size: 14, color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Требует контакты',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Редактировать'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить'),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showAddEditDialog(outlet);
                              } else if (value == 'delete') {
                                _showDeleteDialog(outlet);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Добавить торговую точку',
      ),
    );
  }
} 