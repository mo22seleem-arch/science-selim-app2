import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import 'auth_repository.dart';

class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState() => _R(); }
class _R extends State<RegisterScreen> {
  final _k = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController(), _pass = TextEditingController(), _pass2 = TextEditingController();
  bool _busy = false; String? _err;

  Future<void> _go() async {
    if (!_k.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    try {
      await AuthRepository().signUp(name: _name.text, phone: _phone.text, password: _pass.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);   // AuthGate swaps to Home
    } catch (e) { setState(() => _err = '$e'); }
    if (mounted) setState(() => _busy = false);
  }

  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('إنشاء حساب')),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(key: _k, child: Column(children: [
      if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_err!, style: const TextStyle(color: AppColors.error))),
      TextFormField(controller: _name, validator: Validators.tripleName, textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'الاسم الثلاثي', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 14),
      TextFormField(controller: _phone, keyboardType: TextInputType.phone, validator: Validators.phone,
          decoration: const InputDecoration(labelText: 'رقم الهاتف (010 / 011 / 012 / 015)', prefixIcon: Icon(Icons.phone_android))),
      const SizedBox(height: 14),
      TextFormField(controller: _pass, obscureText: true, validator: Validators.password,
          decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline))),
      const SizedBox(height: 14),
      TextFormField(controller: _pass2, obscureText: true, validator: (v) => v == _pass.text ? null : 'كلمتا المرور غير متطابقتين',
          decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock_outline))),
      const SizedBox(height: 22),
      ElevatedButton(onPressed: _busy ? null : _go, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('إنشاء الحساب')),
    ])))));
}
