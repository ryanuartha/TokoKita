import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/user_role.dart';

class AuthenticatedProfile {
  const AuthenticatedProfile({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
  });

  final String userId;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
}

class AuthService {
  static const emailConfirmationRedirectUri = 'id.tokokita.app://auth-callback';

  static SupabaseClient get client {
    if (!AppConfig.isSupabaseConfigured) {
      throw StateError(
        'Supabase belum terbaca. Jalankan dari folder Front-End dengan '
        'flutter run --dart-define-from-file=config/local.json.',
      );
    }
    return Supabase.instance.client;
  }

  static User? get currentUser => AppConfig.isSupabaseConfigured
      ? Supabase.instance.client.auth.currentUser
      : null;

  static Future<AuthenticatedProfile?> loadCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final profile = await client
        .from('profiles')
        .select('full_name, role')
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) {
      throw StateError(
        'Profil akun belum tersedia. Pastikan migrasi Supabase sudah diterapkan.',
      );
    }

    final roleValue = profile['role'] as String?;
    if (roleValue != 'admin' && roleValue != 'customer') {
      throw StateError('Peran akun Supabase tidak valid.');
    }
    final metadataName = user.userMetadata?['full_name'] as String?;
    final profileName = profile['full_name'] as String?;
    final metadataPhone = user.userMetadata?['phone'] as String?;

    return AuthenticatedProfile(
      userId: user.id,
      email: user.email ?? '',
      fullName: (metadataName?.trim().isNotEmpty ?? false)
          ? metadataName!.trim()
          : (profileName?.trim().isNotEmpty ?? false)
          ? profileName!.trim()
          : user.email?.split('@').first ?? 'Pengguna TokoKita',
      phone: metadataPhone?.trim() ?? '',
      role: roleValue == 'admin' ? UserRole.admin : UserRole.customer,
    );
  }

  static Future<void> deleteCurrentAccount({required String password}) async {
    final user = currentUser;
    if (user?.email == null) {
      throw StateError('Akun email tidak ditemukan. Silakan masuk kembali.');
    }

    try {
      await client.functions.invoke(
        'delete-account',
        body: {'password': password},
      );
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw StateError(details['error'] as String);
      }
      if (error.status == 409) {
        throw StateError(
          'Selesaikan atau batalkan pesanan yang masih berjalan terlebih dahulu.',
        );
      }
      rethrow;
    }

    await client.auth.signOut(scope: SignOutScope.local);
  }
}
