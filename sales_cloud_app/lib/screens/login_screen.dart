import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String phone = '';
  String smsCode = '';
  String verificationId = '';
  bool codeSent = false;

  void verifyPhone() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        goToHome();
      },
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка: \${e.message}")),
        );
      },
      codeSent: (id, _) {
        setState(() {
          verificationId = id;
          codeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (id) => verificationId = id,
    );
  }

  void signInWithCode() async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    goToHome();
  }

  void goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Вход по номеру")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!codeSent)
              TextField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: "Номер телефона"),
                onChanged: (v) => phone = v,
              ),
            if (codeSent)
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Код из SMS"),
                onChanged: (v) => smsCode = v,
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => codeSent ? signInWithCode() : verifyPhone(),
              child: Text(codeSent ? "Подтвердить" : "Получить код"),
            ),
          ],
        ),
      ),
    );
  }
}