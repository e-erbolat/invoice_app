import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Регистрация пользователя с ролью
  Future<AppUser?> registerWithEmail(String email, String password, String role) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user != null) {
        String? salesRepId;
        
        // Если это торговый представитель, создаем запись в sales_reps
        if (role == 'sales') {
          salesRepId = await _createSalesRep(user.uid, email);
        }
        
        final appUser = AppUser(
          uid: user.uid, 
          email: user.email ?? '', 
          role: role,
          salesRepId: salesRepId,
        );
        
        await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
        return appUser;
      }
      return null;
    } catch (e) {
      print('Ошибка регистрации: $e');
      rethrow;
    }
  }
  
  // Создание торгового представителя
  Future<String> _createSalesRep(String userId, String email) async {
    try {
      // Генерируем уникальный ID для торгового представителя
      final salesRepId = 'sales_rep_${DateTime.now().millisecondsSinceEpoch}';
      
      // Создаем базовую запись торгового представителя
      final salesRepData = {
        'id': salesRepId,
        'name': 'Новый представитель', // Пользователь сможет изменить позже
        'phone': '',
        'email': email,
        'region': 'Не указан',
        'commissionRate': 0.0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'userId': userId, // Связываем с пользователем
      };
      
      await _firestore.collection('sales_reps').doc(salesRepId).set(salesRepData);
      print('✅ Создан торговый представитель с ID: $salesRepId');
      
      return salesRepId;
    } catch (e) {
      print('❌ Ошибка создания торгового представителя: $e');
      rethrow;
    }
  }

  // Вход пользователя
  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user != null) {
        return await getUserByUid(user.uid);
      }
      return null;
    } catch (e) {
      print('Ошибка входа: $e');
      rethrow;
    }
  }

  // Получить текущего пользователя и его роль
  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await getUserByUid(user.uid);
    }
    return null;
  }

  // Получить пользователя по uid
  Future<AppUser?> getUserByUid(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromMap(doc.data()!);
    }
    return null;
  }

  // Выход
  Future<void> signOut() async {
    await _auth.signOut();
  }
} 