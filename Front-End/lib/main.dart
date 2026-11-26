import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'models/user_role.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/product_dashboard.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const TokoKitaApp());
}

class TokoKitaApp extends StatelessWidget {
  const TokoKitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TokoKita',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late Future<AuthenticatedProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService.loadCurrentProfile();
  }

  void _retry() {
    setState(() => _profileFuture = AuthService.loadCurrentProfile());
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isSupabaseConfigured) {
      return const ProductDashboard(
        userName: 'Pengguna TokoKita',
        userEmail: 'pengguna@tokokita.id',
      );
    }

    return FutureBuilder<AuthenticatedProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Kami belum bisa memuat akun Anda.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Periksa koneksi internet, lalu coba lagi.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const ProductDashboard(
            userName: 'Pengguna TokoKita',
            userEmail: 'pengguna@tokokita.id',
          );
        }
        if (profile.role == UserRole.admin) {
          return AdminDashboardScreen(
            adminName: profile.fullName,
            adminEmail: profile.email,
          );
        }
        return ProductDashboard(
          userName: profile.fullName,
          userEmail: profile.email,
          isLoggedIn: true,
        );
      },
    );
  }
}
