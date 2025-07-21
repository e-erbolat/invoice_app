import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/outlet.dart';

class OutletScreen extends StatefulWidget {
  const OutletScreen({Key? key}) : super(key: key);

  @override
  State<OutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<OutletScreen> {
  final CollectionReference outletsRef = FirebaseFirestore.instance.collection('outlets');

  void _showAddOutletDialog() {
    final nameController = TextEditingController();
    final contactNameController = TextEditingController();
    final contactPhoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Добавить торговую точку'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: contactNameController,
                decoration: InputDecoration(labelText: 'Контактное лицо'),
              ),
              TextField(
                controller: contactPhoneController,
                decoration: InputDecoration(labelText: 'Телефон'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Адрес'),
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
              final name = nameController.text.trim();
              final contactName = contactNameController.text.trim();
              final contactPhone = contactPhoneController.text.trim();
              final address = addressController.text.trim();
              if (name.isNotEmpty) {
                await outletsRef.add({
                  'name': name,
                  'contactName': contactName,
                  'contactPhone': contactPhone,
                  'address': address,
                });
                Navigator.pop(context);
              }
            },
            child: Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _showEditOutletDialog(Outlet outlet) {
    final nameController = TextEditingController(text: outlet.name);
    final contactNameController = TextEditingController(text: outlet.contactName);
    final contactPhoneController = TextEditingController(text: outlet.contactPhone);
    final addressController = TextEditingController(text: outlet.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать торговую точку'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: contactNameController,
                decoration: InputDecoration(labelText: 'Контактное лицо'),
              ),
              TextField(
                controller: contactPhoneController,
                decoration: InputDecoration(labelText: 'Телефон'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Адрес'),
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
              final name = nameController.text.trim();
              final contactName = contactNameController.text.trim();
              final contactPhone = contactPhoneController.text.trim();
              final address = addressController.text.trim();
              if (name.isNotEmpty) {
                await outletsRef.doc(outlet.id).update({
                  'name': name,
                  'contactName': contactName,
                  'contactPhone': contactPhone,
                  'address': address,
                });
                Navigator.pop(context);
              }
            },
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _deleteOutlet(Outlet outlet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить торговую точку?'),
        content: Text('Вы уверены, что хотите удалить "${outlet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Удалить'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await outletsRef.doc(outlet.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Торговые точки'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: outletsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Нет торговых точек'));
          }
          final outlets = snapshot.data!.docs.map((doc) => Outlet.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
          return ListView.builder(
            itemCount: outlets.length,
            itemBuilder: (context, index) {
              final outlet = outlets[index];
              return ListTile(
                title: Text(outlet.name),
                subtitle: Text('${outlet.contactName} | ${outlet.contactPhone}\n${outlet.address}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      tooltip: 'Редактировать',
                      onPressed: () => _showEditOutletDialog(outlet),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      tooltip: 'Удалить',
                      onPressed: () => _deleteOutlet(outlet),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOutletDialog,
        child: Icon(Icons.add),
        tooltip: 'Добавить торговую точку',
      ),
    );
  }
} 