import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/security/security_gate.dart';
import 'core/security/security_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_guard.dart';
import 'features/courses/courses_screen.dart';

// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _url = String.fromEnvironment('SUPABASE_URL');
const _anon = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _url, anonKey: _anon);
  runApp(const ScienceApp());
}

class ScienceApp extends StatelessWidget {
  const ScienceApp({super.key});
  @override Widget build(BuildContext c) => MaterialApp(
    title: 'العلوم مع محمد سليم', debugShowCheckedModeBanner: false,
    theme: buildSpaceTheme(), themeMode: ThemeMode.dark,
    locale: const Locale('ar', 'EG'), supportedLocales: const [Locale('ar', 'EG')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),   // forced RTL
    home: const SecurityGate(child: AuthGate()));
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override Widget build(BuildContext c) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (_, __) {
      if (Supabase.instance.client.auth.currentSession == null) { SessionGuard.instance.stop(); return const LoginScreen(); }
      // Claim the device BEFORE the guard starts, so a fresh login never kicks itself.
      return FutureBuilder(
        future: AuthRepository().bindDevice().then((_) { SessionGuard.instance.start(); IntegrityService.attest(); }),
        builder: (_, s) => s.connectionState != ConnectionState.done ? const _Splash()
            : s.hasError ? const LoginScreen() : const HomeScreen());
    });
}

class _Splash extends StatelessWidget { const _Splash(); @override Widget build(BuildContext c) => const Scaffold(body: Center(child: CircularProgressIndicator())); }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>>(
    future: AuthRepository().myProfile(),
    builder: (_, s) => s.hasData ? CoursesScreen(profile: s.data!) : const _Splash());
}
