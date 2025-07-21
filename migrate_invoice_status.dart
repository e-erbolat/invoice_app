import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

class InvoiceStatus {
  static const int review = 1;
  static const int packing = 2;
  static const int delivery = 3;
  static const int delivered = 4;
  static const int cancelled = 5;

  static int fromString(String status) {
    switch (status) {
      case 'на рассмотрении':
        return review;
      case 'на сборке':
        return packing;
      case 'на доставке':
        return delivery;
      case 'доставлен':
        return delivered;
      case 'отменен':
        return cancelled;
      default:
        return review;
    }
  }
}

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final firestore = FirebaseFirestore.instance;
  final invoices = await firestore.collection('invoices').get();

  for (final doc in invoices.docs) {
    final data = doc.data();
    final status = data['status'];
    if (status is String) {
      final newStatus = InvoiceStatus.fromString(status);
      await doc.reference.update({'status': newStatus});
      print('Updated invoice ${doc.id}: $status -> $newStatus');
    }
  }
  print('Migration complete!');
} 