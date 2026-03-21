import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../env/multi_env.dart';
import 'platform_utils.dart';
import 'local_database.dart';
import 'cache_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseService.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  /// Ensures dynamic data intended to be a `List<Map<String, dynamic>>` is safely parsed.
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  AuthService() {
    // Initial load if authenticated
    if (isAuthenticated) {
      loadUserProfile();
    }

    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        loadUserProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        _userProfile = null;
        notifyListeners();
      }
      notifyListeners();
    });
  }

  /// Load or refresh user profile from users table + role from user_roles
  Future<void> loadUserProfile() async {
    try {
      if (currentUser == null) {
        _userProfile = null;
        notifyListeners();
        return;
      }

      // 1. Fetch base profile from the users table
      final response = await _client
          .from('users')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();

      if (response == null) {
        _userProfile = null;
        notifyListeners();
        return;
      }

      // 2. Fetch the user's primary role from user_roles → roles
      String role = 'student'; // default
      try {
        final roleResponse = await _client
            .from('user_roles')
            .select('roles(name)')
            .eq('user_id', currentUser!.id)
            .maybeSingle();

        if (roleResponse != null &&
            roleResponse['roles'] != null &&
            roleResponse['roles']['name'] != null) {
          role = roleResponse['roles']['name'] as String;
        }
      } catch (roleErr) {
        debugPrint('Could not fetch role, attempting to use cached role: $roleErr');
        // Try to get role from cached profile if network fails
        final cached = LocalDatabase().get<Map<String, dynamic>>(CacheKeys.userProfile(currentUser!.id));
        if (cached != null && cached['role'] != null) {
          role = cached['role'];
        }
      }

      // 3. Merge profile + role into a single map
      _userProfile = {
        ...response,
        'role': role,
      };

      // 4. CACHE: Save profile for offline use
      await LocalDatabase().set(CacheKeys.userProfile(currentUser!.id), _userProfile);

      _isOffline = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _isOffline = true;
      
      // Try to load from cache if network fails
      if (currentUser != null) {
        final cached = LocalDatabase().get<Map<String, dynamic>>(CacheKeys.userProfile(currentUser!.id));
        if (cached != null) {
          _userProfile = Map<String, dynamic>.from(cached);
          notifyListeners();
        }
      }
    }
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
      if (currentUser != null) {
        // Clear all local database cache on sign out
        // We use a general clear for security/privacy
        await LocalDatabase().clearAll();
      }
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
          .maybeSingle();

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
      // استخدام OAuth للويب والويندوز والماك
      if (kIsWeb || PlatformUtils.isWindows) {
        String? redirectUrl;
        if (kIsWeb) {
          redirectUrl = 'https://doraty-app.vercel.app/auth/callback';
        } else if (PlatformUtils.isWindows) {
          redirectUrl = 'doraty://callback';
        } else {
          redirectUrl = 'com.doraty.app://callback';
        }

        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
        );
        return null;
      }

      // Native Android & iOS — Google Sign In 6.x
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: PlatformUtils.isIOS ? Env.googleIosClientId : null,
        serverClientId: Env.googleWebClientId,
      );

      debugPrint('🔄 Requesting Google Sign In...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('❌ Google Sign-In was canceled by the user.');
        return null; // User canceled the sign-in flow
      }

      debugPrint('✅ Google User obtained: ${googleUser.email}');

      // في النسخة 6.x، .authentication هو async
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        debugPrint('❌ Error: idToken is null');
        throw 'فشل الحصول على ID Token من جوجل. تأكد من إعداد SHA-1 و Web Client ID بشكل صحيح.';
      }

      debugPrint('✅ idToken obtained. Signing in with Supabase...');

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      // Create or update user profile
      if (response.user != null) {
        await _client.from('users').upsert({
          'id': response.user!.id,
          'email': response.user!.email,
          'full_name': response.user!.userMetadata?['full_name'] ??
              googleUser.displayName,
          'avatar_url':
              response.user!.userMetadata?['avatar_url'] ?? googleUser.photoUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
        await loadUserProfile();
      }

      return response;
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      if (e.toString().contains('canceled') || e.toString().contains('sign_in_canceled')) {
        throw 'تم إلغاء تسجيل الدخول عبر جوجل';
      }
      // إذا كان الخطأ متعلق بالإعدادات، نعطي رسالة أوضح
      if (e.toString().contains('developer_error') || e.toString().contains('10')) {
        throw 'خطأ في إعدادات التطبيق (SHA-1/Client ID). يرجى التأكد من مطابقة بيانات Firebase و Supabase.';
      }
      rethrow;
    }
  }
}
