import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_rep.dart';

class SalesRepScreen extends StatefulWidget {
  const SalesRepScreen({Key? key}) : super(key: key);

  @override
  State<SalesRepScreen> createState() => _SalesRepScreenState();
}

class _SalesRepScreenState extends State<SalesRepScreen> {
  final CollectionReference repsRef = FirebaseFirestore.instance.collection('sales_reps');

  void _showAddRepDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Добавить представителя'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Имя'),
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: 'Телефон'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isNotEmpty) {
                await repsRef.add({
                  'name': name,
                  'phone': phone,
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

  void _showEditRepDialog(SalesRep rep) {
    final nameController = TextEditingController(text: rep.name);
    final phoneController = TextEditingController(text: rep.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать представителя'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Имя'),
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: 'Телефон'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isNotEmpty) {
                await repsRef.doc(rep.id).update({
                  'name': name,
                  'phone': phone,
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

  void _deleteRep(SalesRep rep) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить представителя?'),
        content: Text('Вы уверены, что хотите удалить "${rep.name}"?'),
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
      await repsRef.doc(rep.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Торговые представители'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: repsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Нет представителей'));
          }
          final reps = snapshot.data!.docs.map((doc) => SalesRep.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
          return ListView.builder(
            itemCount: reps.length,
            itemBuilder: (context, index) {
              final rep = reps[index];
              return ListTile(
                title: Text(rep.name),
                subtitle: Text(rep.phone),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      tooltip: 'Редактировать',
                      onPressed: () => _showEditRepDialog(rep),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      tooltip: 'Удалить',
                      onPressed: () => _deleteRep(rep),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRepDialog,
        child: Icon(Icons.add),
        tooltip: 'Добавить представителя',
      ),
    );
  }
} 