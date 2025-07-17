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
        final appUser = AppUser(uid: user.uid, email: user.email ?? '', role: role);
        await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
        return appUser;
      }
      return null;
    } catch (e) {
      print('Ошибка регистрации: $e');
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