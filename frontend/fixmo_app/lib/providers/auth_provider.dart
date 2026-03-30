import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

/// Manages authentication state for the entire app.
///
/// Listens to Supabase auth changes and auto-signs-in anonymously
/// on first launch so every user always has a session/JWT.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _authSub;

  User? _user;
  Session? _session;
  bool _initializing = true;

  AuthProvider() {
    _authSub = _authService.onAuthStateChange.listen(_handleAuthChange);
  }

  // ── Public getters ──────────────────────────────────────────────────

  bool get isInitializing => _initializing;
  bool get isAuthenticated => _session != null;
  bool get isAnonymous => _user != null && (_user!.email == null || _user!.email!.isEmpty);
  bool get isRegistered => _authService.isRegisteredUser;
  User? get user => _user;
  Session? get session => _session;

  /// The JWT access token for backend API calls.
  String? get accessToken => _session?.accessToken;

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Call once after Supabase.initialize() completes.
  /// If no session exists, signs in anonymously.
  Future<void> initialize() async {
    _session = _authService.currentSession;
    _user = _authService.currentUser;

    if (_session == null) {
      await _authService.signInAnonymously();
      _session = _authService.currentSession;
      _user = _authService.currentUser;
    }

    _initializing = false;
    notifyListeners();
  }

  // ── Auth actions ────────────────────────────────────────────────────

  Future<void> signInAnonymously() async {
    await _authService.signInAnonymously();
  }

  Future<void> linkEmail(String email, String password) async {
    await _authService.linkEmail(email, password);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _authService.signInWithEmail(email, password);
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  // ── Internal ────────────────────────────────────────────────────────

  void _handleAuthChange(AuthState state) {
    _session = state.session;
    _user = state.session?.user;
    debugPrint('Auth state changed: ${state.event}');
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
