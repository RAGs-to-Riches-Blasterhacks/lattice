import 'package:flutter/foundation.dart';
import 'package:lattice/models/user.dart';
import 'package:lattice/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;

  User? _user;
  String? _token;
  bool _loading = true;

  AuthProvider(this._api) {
    _tryRestoreSession();
  }

  User? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;
  bool get loading => _loading;

  Future<void> _tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _api.setAuthToken(token);
      try {
        _user = await _api.getMe();
        _token = token;
      } catch (_) {
        await prefs.remove('auth_token');
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
    _api.setAuthToken(auth.idToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', auth.idToken);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _api.setAuthToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token == null) return;
    _user = await _api.getMe();
    notifyListeners();
  }
}
