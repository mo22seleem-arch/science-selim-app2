import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import 'auth_repository.dart';
import 'register_screen.dart';
import 'session_guard.dart';

class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _S(); }
class _S extends State<LoginScreen> {
  final _k = GlobalKey<FormState>(); final _phone = TextEditingController(), _pass = TextEditingController();
  bool _busy = false, _hide = true; String? _err;

  Future<void> _go() async {
    if (!_k.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    SessionGuard.kicked.value = false;
    try { await AuthRepository().signIn(phone: _phone.text, password: _pass.text); } // AuthGate binds the device
    catch (e) { setState(() => _err = '$e'); }
    if (mounted) setState(() => _busy = false);
  }

  @override Widget build(BuildContext c) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: Form(key: _k, child: Column(children: [
      const Icon(Icons.science_outlined, size: 76, color: AppColors.cream),
      const SizedBox(height: 12),
      Text('العلوم مع محمد سليم', style: Theme.of(c).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 28),
      ValueListenableBuilder<bool>(valueListenable: SessionGuard.kicked, builder: (_, k, __) => k
        ? _banner('تم تسجيل الدخول إلى حسابك من جهاز آخر، لذلك تم إنهاء الجلسة على هذا الجهاز.') : const SizedBox()),
      if (_err != null) _banner(_err!),
      TextFormField(controller: _phone, keyboardType: TextInputType.phone, validator: Validators.phone,
          decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_android))),
      const SizedBox(height: 14),
      TextFormField(controller: _pass, obscureText: _hide, validator: (v) => (v ?? '').isEmpty ? 'أدخل كلمة المرور' : null,
          decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)))),
      const SizedBox(height: 22),
      ElevatedButton(onPressed: _busy ? null : _go, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تسجيل الدخول')),
      TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: const Text('ليس لديك حساب؟ أنشئ حساباً', style: TextStyle(color: AppColors.cream))),
    ]))))));

  Widget _banner(String m) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error)),
      child: Text(m, style: const TextStyle(color: AppColors.error)));
}
