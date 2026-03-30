import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth.
///
/// All auth mutations go through this service so the rest of the app
/// never touches `Supabase.instance.client.auth` directly.
class AuthService {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  /// Current Supabase session (null if not signed in).
  Session? get currentSession => _auth.currentSession;

  /// Current user (null if not signed in).
  User? get currentUser => _auth.currentUser;

  /// Bearer token for backend API calls.
  /// Returns null when no active session exists.
  String? get accessToken => currentSession?.accessToken;

  /// Stream of auth state changes (sign-in, sign-out, token refresh).
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// Sign in anonymously.
  ///
  /// Requires "Allow anonymous sign-ins" to be enabled in
  /// Supabase Dashboard → Authentication → Providers.
  /// Returns the new session, or null if sign-in fails.
  Future<Session?> signInAnonymously() async {
    try {
      final response = await _auth.signInAnonymously();
      debugPrint('Anonymous sign-in succeeded');
      return response.session;
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      return null;
    }
  }

  /// Upgrade the current anonymous user to an email/password account.
  Future<UserResponse> linkEmail(String email, String password) async {
    return _auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  /// Sign in with email + password (for returning registered users).
  Future<Session?> signInWithEmail(String email, String password) async {
    final response = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.session;
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
    debugPrint('User signed out');
  }

  /// Returns true if the current session has a non-anonymous user with an email.
  bool get isRegisteredUser {
    final user = currentUser;
    if (user == null) return false;
    return user.email != null && user.email!.isNotEmpty;
  }
}
