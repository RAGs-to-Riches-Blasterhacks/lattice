import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lattice/models/user.dart';
import 'package:lattice/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;

  User? _user;
  String? _token;
  bool _loading = true;

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';

  AuthProvider(this._api) {
    _api.onAuthExpired = _onAuthExpired;
    _tryRestoreSession();
  }

  User? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;
  bool get loading => _loading;

  /// Called by ApiService when token refresh fails — force logout.
  void _onAuthExpired() {
    logout();
  }

  Future<void> _tryRestoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (token != null) {
      _api.setAuthToken(token, refreshToken: refreshToken);
      try {
        _user = await _api.getMe();
        _token = token;
        // If the token was refreshed during getMe, persist the new tokens
        await _persistTokensIfRefreshed();
      } catch (_) {
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _refreshTokenKey);
        _api.setAuthToken(null);
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final auth = await _api.login(email: email, password: password);
    await _saveSession(auth);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final auth = await _api.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _saveSession(auth);
  }

  Future<void> _saveSession(AuthResponse auth) async {
    _token = auth.idToken;
    _user = auth.user;
    _api.setAuthToken(auth.idToken, refreshToken: auth.refreshToken);
    await _storage.write(key: _tokenKey, value: auth.idToken);
    await _storage.write(key: _refreshTokenKey, value: auth.refreshToken);
    notifyListeners();
  }

  /// After any API call, the token may have been silently refreshed.
  /// Persist the latest tokens so the next app launch uses them.
  Future<void> _persistTokensIfRefreshed() async {
    final currentToken = _api.authToken;
    if (currentToken != null && currentToken != _token) {
      _token = currentToken;
      await _storage.write(key: _tokenKey, value: currentToken);
      final currentRefresh = _api.refreshToken;
      if (currentRefresh != null) {
        await _storage.write(key: _refreshTokenKey, value: currentRefresh);
      }
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _api.setAuthToken(null);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token == null) return;
    _user = await _api.getMe();
    await _persistTokensIfRefreshed();
    notifyListeners();
  }
}
