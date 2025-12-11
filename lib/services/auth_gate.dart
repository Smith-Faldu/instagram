import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/home.dart';
import '../ui/login.dart';

/// Simple wrapper around Supabase auth.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final SupabaseClient _client = Supabase.instance.client;

  Stream<AuthState> get authState => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  /// SIGN IN
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final session = response.session;
    if (session == null) {
      throw AuthException('Sign-in failed');
    }

    final user = session.user;
    if (user != null) {
      await _ensureUserRecord(
        authId: user.id,
        email: user.email ?? email,
      );
    }
  }

  /// SIGN UP
  Future<void> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );

    final user = response.user;

    if (user != null) {
      await _ensureUserRecord(
        authId: user.id,
        email: user.email ?? email,
        username: (data?['username'] as String?) ?? email.split('@').first,
        fullName: data?['full_name'] as String?,
        profilePic: data?['profile_pic'] as String?,
      );
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Ensure a row exists in public.user for this auth_id.
  Future<void> _ensureUserRecord({
    required String authId,
    required String email,
    String? username,
    String? fullName,
    String? profilePic,
  }) async {
    try {
      final existing = await _client
          .from('user')
          .select('id')
          .eq('auth_id', authId)
          .maybeSingle();

      if (existing != null) return;

      final safeUsername = (username ?? email.split('@').first).trim();

      await _client.from('user').insert({
        'auth_id': authId,
        'email_id': email,
        'username': safeUsername,
        'full_name': fullName,
        'profile_pic': profilePic,
      });
    } catch (e) {
      // Log the error but don't block auth flow
      debugPrint('Error ensuring user record: $e');
      rethrow;
    }
  }
}

/// ✅ CORRECT auth routing using stream state
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.instance.authState,
      builder: (context, snapshot) {
        // ✅ Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ✅ Check for active session
        final session = snapshot.data?.session;

        if (session != null) {
          return const HomePage();
        }

        return const Login();
      },
    );
  }
}