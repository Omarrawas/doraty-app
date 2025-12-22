import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseService.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  AuthService() {
    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String branch,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'branch': branch,
        },
      );

      // Create user profile in users table if user exists
      if (response.user != null) {
        try {
          await _client.from('users').insert({
            'id': response.user!.id,
            'email': email,
            'full_name': fullName,
            'branch': branch,
          });
        } catch (dbError) {
          // If insertion fails due to existing user in database,
          // update the existing record instead of failing signup
          try {
            await _client.from('users').update({
              'full_name': fullName,
              'branch': branch,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('email', email);
          } catch (updateError) {
            // Clean up: if we can't even update, delete the auth user
            try {
              await _client.auth.admin.deleteUser(response.user!.id);
            } catch (_) {}
            // Re-throw the original error
            rethrow;
          }
        }
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  /// Get user profile from users table
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      final response = await _client
          .from('users')
          .select()
          .eq('id', currentUser!.id)
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    try {
      if (currentUser == null) return;

      await _client.from('users').update(data).eq('id', currentUser!.id);
    } catch (e) {
      rethrow;
    }
  }
}
