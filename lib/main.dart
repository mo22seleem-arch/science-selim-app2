import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/security/security_gate.dart';
import 'core/security/security_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_guard.dart';
import 'features/courses/grades_screen.dart';
import 'features/splash/splash_screen.dart';

// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _url = String.fromEnvironment('SUPABASE_URL');
const _anon = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_url.isEmpty || _anon.isEmpty) { runApp(const _App(home: _MissingConfig())); return; }   // no silent crash if the build forgot the keys
  await Supabase.initialize(url: _url, anonKey: _anon);
  runApp(const _App(home: SplashScreen(next: SecurityGate(child: AuthGate()))));
}

class _App extends StatelessWidget {
  final Widget home;
  const _App({required this.home});
  @override Widget build(BuildContext c) => MaterialApp(
    title: 'العلوم مع محمد سليم', debugShowCheckedModeBanner: false,
    theme: buildSpaceTheme(), themeMode: ThemeMode.dark,
    locale: const Locale('ar', 'EG'), supportedLocales: const [Locale('ar', 'EG')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),   // forced RTL
    home: home);
}

class _MissingConfig extends StatelessWidget {
  const _MissingConfig();
  @override Widget build(BuildContext c) => const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(28), child: Text(
    'إعدادات الاتصال ناقصة.\nأعد بناء التطبيق مع تمرير SUPABASE_URL و SUPABASE_ANON_KEY (--dart-define).',
    textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.8)))));
}

class AuthGate extends StatefulWidget { const AuthGate({super.key}); @override State<AuthGate> createState() => _AG(); }
class _AG extends State<AuthGate> {
  Future<void>? _bind; String? _uid;

  // Claim this device BEFORE the guard starts, so a fresh login never kicks itself. Runs once per signed-in user.
  Future<void> _doBind() async {
    await AuthRepository().bindDevice();
    SessionGuard.instance.start();
    IntegrityService.attest();
  }

  @override Widget build(BuildContext c) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (_, __) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) { _bind = null; _uid = null; SessionGuard.instance.stop(); return const LoginScreen(); }
      if (_uid != session.user.id) { _uid = session.user.id; _bind = _doBind(); }
      return FutureBuilder<void>(future: _bind, builder: (_, f) {
        if (f.connectionState != ConnectionState.done) return const _Splash();
        if (f.hasError) {   // e.g. banned account / network: don't stay half-logged-in
          WidgetsBinding.instance.addPostFrameCallback((_) { Supabase.instance.client.auth.signOut(); });
          return const LoginScreen();
        }
        return const HomeScreen();
      });
    });
}

class _Splash extends StatelessWidget { const _Splash(); @override Widget build(BuildContext c) => const Scaffold(body: Center(child: CircularProgressIndicator())); }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>>(
    future: AuthRepository().myProfile(),
    builder: (_, s) => s.hasData ? GradesScreen(profile: s.data!) : const _Splash());
}
