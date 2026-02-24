import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../env/multi_env.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseService.instance.client;
  static bool _googleSignInInitialized = false;

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

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );

      // Create user profile in users table if user exists
      if (response.user != null) {
        try {
          await _client.from('users').insert({
            'id': response.user!.id,
            'email': email,
            'full_name': fullName,
          });
        } catch (dbError) {
          // If insertion fails due to existing user in database,
          // update the existing record instead of failing signup
          try {
            await _client.from('users').update({
              'full_name': fullName,
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

  /// Delete account
  Future<void> deleteAccount() async {
    try {
      if (currentUser == null) return;

      // First delete from users table
      await _client.from('users').delete().eq('id', currentUser!.id);

      // Sign out
      await signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with Google
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      // استخدام OAuth للويب والويندوز والماك (المنصات التي لا تدعم google_sign_in مباشرة)
      if (kIsWeb || (defaultTargetPlatform == TargetPlatform.windows)) {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          // للويب نستخدم رابط Vercel، للويندوز نتركها لـ Supabase للتعامل معها أو نستخدم الرابط الافتراضي
          redirectTo: kIsWeb ? 'https://doraty.vercel.app' : null,
        );
        return null;
      }

      // Native implementation for Android & iOS
      final googleSignIn = GoogleSignIn.instance;

      if (!_googleSignInInitialized) {
        await googleSignIn.initialize(
          clientId: Env.googleIosClientId, // Required for iOS
          serverClientId:
              Env.googleWebClientId, // Required to get idToken for Supabase
        );
        _googleSignInInitialized = true;
      }
      
      final googleUser = await googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'فشل الحصول على رمز الهوية من جوجل';
      }

      // In v7.2.0, accessToken is not in GoogleSignInAuthentication. 
      // We need to request it via the authorization client if Supabase needs it.
      final authz = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'openid',
        'profile',
      ]);
      final accessToken = authz.accessToken;

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Create or update user profile after social login
      if (response.user != null) {
        await _client.from('users').upsert({
          'id': response.user!.id,
          'email': response.user!.email,
          'full_name': response.user!.userMetadata?['full_name'] ?? googleUser.displayName,
          'avatar_url': response.user!.userMetadata?['avatar_url'] ?? googleUser.photoUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
