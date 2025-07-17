import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService().registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        'sales', // всегда торговый
      );
      await AuthService().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      setState(() {
        _error = 'Ошибка регистрации: ${e.toString()}';
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
      appBar: AppBar(title: Text('Регистрация')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v != null && v.contains('@') ? null : 'Введите корректный email',
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Пароль'),
                  obscureText: true,
                  validator: (v) => v != null && v.length >= 6 ? null : 'Минимум 6 символов',
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  decoration: InputDecoration(labelText: 'Подтвердите пароль'),
                  obscureText: true,
                  validator: (v) => v == _passwordController.text ? null : 'Пароли не совпадают',
                ),
                SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Colors.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Зарегистрироваться'),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pushReplacementNamed(context, '/login'),
                  child: Text('Уже есть аккаунт? Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 