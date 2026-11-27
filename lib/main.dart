import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/utils/notification_service.dart';
import 'features/auth/views/login_screen.dart';
import 'features/badges/controllers/badge_controller.dart';
import 'features/badges/models/badge_model.dart';
import 'shared/root_navigation.dart';

/// Flag global status inisialisasi Supabase agar aman saat offline/tanpa .env.
bool isSupabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load .env (coba .env lalu fallback .env.example)
  debugPrint('[INIT] 1. Dotenv');
  try {
    await dotenv.load(fileName: '.env').timeout(const Duration(seconds: 3));
  } catch (_) {
    try {
      await dotenv
          .load(fileName: '.env.example')
          .timeout(const Duration(seconds: 3));
    } catch (e, st) {
      debugPrint('[INIT] Dotenv skip/error: $e\n$st');
    }
  }

  // 2. Initialize Hive & register TypeAdapter
  debugPrint('[INIT] 2. Hive');
  try {
    await Hive.initFlutter().timeout(const Duration(seconds: 3));
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BadgeModelAdapter());
    }
    await BadgeController.instance.init().timeout(const Duration(seconds: 3));
  } catch (e, st) {
    debugPrint('[INIT] Hive init error: $e\n$st');
  }

  // 3. Initialize Supabase hanya jika URL valid & Anon Key terisi
  debugPrint('[INIT] 3. Supabase');
  isSupabaseReady = false;
  try {
    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    final uri = Uri.tryParse(supabaseUrl);
    final isValidUrl = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && isValidUrl) {
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      ).timeout(const Duration(seconds: 3));
      isSupabaseReady = true;
    } else {
      debugPrint(
        '[INIT] Supabase dilewati: URL/Key kosong atau tidak valid (mode lokal aktif).',
      );
    }
  } catch (e, st) {
    isSupabaseReady = false;
    debugPrint('[INIT] Supabase init error: $e\n$st');
  }

  // 4. Initialize notification service dengan timeout agar tidak memblokir runApp
  debugPrint('[INIT] 4. Notification');
  try {
    await NotificationService.initNotification()
        .timeout(const Duration(seconds: 3));
  } catch (e, st) {
    debugPrint('[INIT] Notification init error/timeout: $e\n$st');
  }

  // 5. Jalankan aplikasi
  debugPrint('[INIT] 5. runApp');
  runApp(const GeezusApp());
}

class GeezusApp extends StatelessWidget {
  const GeezusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geezus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF6C5CE7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFF9C88FF),
          surface: Color(0xFF1E1E2C),
        ),
      ),
      home: const _StartupRouter(),
    );
  }
}

/// Mengecek sesi pengguna lalu mengarahkan ke RootNavigation atau LoginScreen.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    bool loggedIn = false;

    try {
      // Pastikan frame pertama selesai dirender sebelum Navigator.pushReplacement
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 1. Cek sesi Supabase hanya jika Supabase berhasil diinisialisasi
      if (isSupabaseReady) {
        try {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            loggedIn = true;
          }
        } catch (e) {
          debugPrint('[STARTUP] Cek sesi Supabase gagal: $e');
        }
      }

      // 2. Fallback ke sesi lokal di FlutterSecureStorage
      if (!loggedIn) {
        try {
          const storage = FlutterSecureStorage();
          final activeEmail = await storage
              .read(key: 'active_email')
              .timeout(const Duration(seconds: 3));
          if (activeEmail != null && activeEmail.isNotEmpty) {
            loggedIn = true;
          }
        } catch (e) {
          debugPrint('[STARTUP] Cek sesi lokal gagal: $e');
        }
      }
    } catch (e, st) {
      debugPrint('[STARTUP] Error tidak terduga di _checkSession: $e\n$st');
    } finally {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                loggedIn ? const RootNavigation() : const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flash_on, size: 70, color: Color(0xFF6C5CE7)),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            SizedBox(height: 16),
            Text(
              'Memuat Geezus...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
