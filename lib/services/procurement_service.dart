import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/procurement.dart';
import '../models/purchase_source.dart';

class ProcurementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<PurchaseSource>> getSources() async {
    final snap = await _firestore.collection('purchase_sources').get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return PurchaseSource.fromMap(data);
    }).toList();
  }

  Future<void> addSource(PurchaseSource source) async {
    await _firestore.collection('purchase_sources').add(source.toMap());
  }

  Future<void> updateSource(PurchaseSource source) async {
    await _firestore.collection('purchase_sources').doc(source.id).update(source.toMap());
  }

  Future<void> deleteSource(String sourceId) async {
    await _firestore.collection('purchase_sources').doc(sourceId).delete();
  }

  Future<void> createProcurement(Procurement procurement) async {
    await _firestore.collection('procurements').doc(procurement.id).set(procurement.toMap());
  }

  Future<List<Procurement>> getProcurements() async {
    final snap = await _firestore.collection('procurements').orderBy('date', descending: true).get();
    return snap.docs.map((d) => Procurement.fromMap(d.data())).toList();
  }

  Future<List<Procurement>> getProcurementsByStatus(int status) async {
    try {
      final snap = await _firestore
          .collection('procurements')
          .where('status', isEqualTo: status)
          .get()
          .timeout(const Duration(seconds: 20));
      final list = snap.docs.map((d) => Procurement.fromMap(d.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } on Exception {
      // Возвращаем пустой список при ошибке/таймауте, чтобы не зависал экран
      return [];
    }
  }

  Future<void> updateProcurementStatus(String id, int status) async {
    await _firestore.collection('procurements').doc(id).update({'status': status});
  }
}


