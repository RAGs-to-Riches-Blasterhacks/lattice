import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lattice/models/conversation.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/models/streak.dart';
import 'package:lattice/models/user_stats.dart';
import 'package:lattice/models/user.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  ); //URL 10.0.2.2 for Android simulation

  static const String _firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  String? _authToken;
  String? _refreshToken;

  /// Callback invoked when token refresh fails (e.g. refresh token expired).
  /// AuthProvider sets this to trigger logout.
  void Function()? onAuthExpired;

  void setAuthToken(String? token, {String? refreshToken}) {
    _authToken = token;
    if (refreshToken != null) _refreshToken = refreshToken;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// Attempt to refresh the Firebase ID token using the stored refresh token.
  /// Returns true if successful.
  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null || _firebaseApiKey.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse(
          'https://securetoken.googleapis.com/v1/token?key=$_firebaseApiKey',
        ),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=refresh_token&refresh_token=$_refreshToken',
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _authToken = data['id_token'] as String;
        _refreshToken = data['refresh_token'] as String;
        return true;
      }
    } catch (_) {
      // Refresh failed — caller will handle
    }
    return false;
  }

  /// The current auth and refresh tokens (for persisting after a refresh).
  String? get authToken => _authToken;
  String? get refreshToken => _refreshToken;

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response, {
    Future<http.Response> Function()? retry,
  }) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    // On 401, attempt a single token refresh + retry
    if (response.statusCode == 401 && retry != null) {
      if (await _tryRefreshToken()) {
        final retryResp = await retry();
        if (retryResp.statusCode >= 200 && retryResp.statusCode < 300) {
          if (retryResp.body.isEmpty) return {};
          return jsonDecode(retryResp.body) as Map<String, dynamic>;
        }
      }
      // Refresh failed or retry failed — session is dead
      onAuthExpired?.call();
    }
    String message;
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] as String? ?? response.body;
    } catch (_) {
      message = response.body;
    }
    throw ApiException(response.statusCode, message);
  }

  Future<List<dynamic>> _handleListResponse(
    http.Response response, {
    Future<http.Response> Function()? retry,
  }) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    if (response.statusCode == 401 && retry != null) {
      if (await _tryRefreshToken()) {
        final retryResp = await retry();
        if (retryResp.statusCode >= 200 && retryResp.statusCode < 300) {
          return jsonDecode(retryResp.body) as List<dynamic>;
        }
      }
      onAuthExpired?.call();
    }
    String message;
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] as String? ?? response.body;
    } catch (_) {
      message = response.body;
    }
    throw ApiException(response.statusCode, message);
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String displayName,
    String? timezone,
    Map<String, dynamic>? location,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'display_name': displayName,
    };
    if (timezone != null) body['timezone'] = timezone;
    if (location != null) body['location'] = location;
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = await _handleResponse(response);
    return AuthResponse.fromJson(data);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    final data = await _handleResponse(response);
    return AuthResponse.fromJson(data);
  }

  Future<AuthResponse> oauthLogin({
    required String idToken,
    required String provider,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/oauth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_token': idToken,
        'provider': provider,
      }),
    );
    final data = await _handleResponse(response);
    return AuthResponse.fromJson(data);
  }

  // ── Users ────────────────────────────────────────────────────────────────

  Future<User> getMe() async {
    request() => http.get(Uri.parse('$_baseUrl/users/me'), headers: _headers);
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return User.fromJson(data);
  }

  Future<User> updateMe(Map<String, dynamic> updates) async {
    request() => http.patch(
          Uri.parse('$_baseUrl/users/me'),
          headers: _headers,
          body: jsonEncode(updates),
        );
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return User.fromJson(data);
  }

  // ── Plans ────────────────────────────────────────────────────────────────

  Future<List<PlanSummary>> listPlans() async {
    request() => http.get(Uri.parse('$_baseUrl/plans'), headers: _headers);
    final response = await request();
    final data = await _handleListResponse(response, retry: request);
    return data
        .map((p) => PlanSummary.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<Plan> getPlan(String planId) async {
    request() =>
        http.get(Uri.parse('$_baseUrl/plans/$planId'), headers: _headers);
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Plan.fromJson(data);
  }

  Future<Plan> createPlan({
    required String skillName,
    String? description,
    required int daysPerWeek,
    required int minutesPerDay,
  }) async {
    final body = jsonEncode({
      'skill_name': skillName,
      if (description != null) 'description': description,
      'success_levels': {
        'should_know': [],
        'might_know': [],
        'should_know_next': [],
      },
      'days_per_week': daysPerWeek,
      'minutes_per_day': minutesPerDay,
    });
    request() =>
        http.post(Uri.parse('$_baseUrl/plans'), headers: _headers, body: body);
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Plan.fromJson(data);
  }

  Future<void> deletePlan(String planId) async {
    request() =>
        http.delete(Uri.parse('$_baseUrl/plans/$planId'), headers: _headers);
    final response = await request();
    if (response.statusCode == 401) {
      if (await _tryRefreshToken()) {
        final retryResp = await request();
        if (retryResp.statusCode == 204) return;
        await _handleResponse(retryResp);
        return;
      }
      onAuthExpired?.call();
    }
    if (response.statusCode != 204) {
      await _handleResponse(response);
    }
  }

  Future<Plan> editNode(
    String planId,
    String nodeId,
    Map<String, dynamic> changes,
  ) async {
    final body = jsonEncode(changes);
    request() => http.patch(
          Uri.parse('$_baseUrl/plans/$planId/nodes/$nodeId'),
          headers: _headers,
          body: body,
        );
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Plan.fromJson(data);
  }

  Future<Plan> addNote(
    String planId,
    String nodeId,
    String content,
  ) async {
    final body = jsonEncode({'content': content});
    request() => http.post(
          Uri.parse('$_baseUrl/plans/$planId/nodes/$nodeId/notes'),
          headers: _headers,
          body: body,
        );
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Plan.fromJson(data);
  }

  Future<Plan> switchBranch(String planId, String branchId) async {
    final body = jsonEncode({'branch_id': branchId});
    request() => http.post(
          Uri.parse('$_baseUrl/plans/$planId/switch-branch'),
          headers: _headers,
          body: body,
        );
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Plan.fromJson(data);
  }

  Future<Map<String, dynamic>> logProgress(
    String planId,
    String nodeId, {
    required String status,
    String? note,
  }) async {
    final body = jsonEncode({
      'status': status,
      if (note != null) 'note': note,
    });
    request() => http.post(
          Uri.parse('$_baseUrl/plans/$planId/nodes/$nodeId/progress'),
          headers: _headers,
          body: body,
        );
    final response = await request();
    return _handleResponse(response, retry: request);
  }

  // ── Conversations ────────────────────────────────────────────────────────

  Future<Conversation> createConversation({String? planId}) async {
    final uri = planId != null
        ? Uri.parse('$_baseUrl/conversations?plan_id=$planId')
        : Uri.parse('$_baseUrl/conversations');
    request() => http.post(uri, headers: _headers);
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Conversation.fromJson(data);
  }

  Future<List<Conversation>> listConversations({
    String? planId,
    bool activeOnly = true,
  }) async {
    final params = <String, String>{};
    if (planId != null) params['plan_id'] = planId;
    if (!activeOnly) params['active_only'] = 'false';
    final uri =
        Uri.parse('$_baseUrl/conversations').replace(queryParameters: params);
    request() => http.get(uri, headers: _headers);
    final response = await request();
    final data = await _handleListResponse(response, retry: request);
    return data
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<Conversation> sendMessage(
    String conversationId, {
    required String content,
    String role = 'user',
  }) async {
    final body = jsonEncode({'role': role, 'content': content});
    request() => http.post(
          Uri.parse('$_baseUrl/conversations/$conversationId/messages'),
          headers: _headers,
          body: body,
        );
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Conversation.fromJson(data);
  }

  // ── Friends ─────────────────────────────────────────────────────────────

  Future<String> getMyFriendCode() async {
    request() =>
        http.get(Uri.parse('$_baseUrl/friends/code'), headers: _headers);
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return data['friend_code'] as String;
  }

  Future<List<Map<String, dynamic>>> listFriends() async {
    request() => http.get(Uri.parse('$_baseUrl/friends'), headers: _headers);
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return (data['friends'] as List<dynamic>)
        .map((f) => f as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> addFriend(String friendCode) async {
    final body = jsonEncode({'friend_code': friendCode});
    request() => http.post(
          Uri.parse('$_baseUrl/friends/add'),
          headers: _headers,
          body: body,
        );
    final response = await request();
    return _handleResponse(response, retry: request);
  }

  Future<void> removeFriend(String userId) async {
    request() =>
        http.delete(Uri.parse('$_baseUrl/friends/$userId'), headers: _headers);
    final response = await request();
    if (response.statusCode == 401) {
      if (await _tryRefreshToken()) {
        final retryResp = await request();
        if (retryResp.statusCode == 204) return;
        await _handleResponse(retryResp);
        return;
      }
      onAuthExpired?.call();
    }
    if (response.statusCode != 204) {
      await _handleResponse(response);
    }
  }

  // ── Streaks ──────────────────────────────────────────────────────────────

  Future<UserStats> getMyStats() async {
    request() =>
        http.get(Uri.parse('$_baseUrl/streaks/me/stats'), headers: _headers);
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return UserStats.fromJson(data);
  }

  Future<Streak> getMyStreak() async {
    request() => http.get(Uri.parse('$_baseUrl/streaks/me'), headers: _headers);
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Streak.fromJson(data);
  }

  Future<Streak> checkIn({
    required String planId,
    required String nodeId,
    String? note,
  }) async {
    final body = jsonEncode({
      'plan_id': planId,
      'node_id': nodeId,
      if (note != null) 'note': note,
    });
    request() => http.post(
          Uri.parse('$_baseUrl/streaks/check-in'),
          headers: _headers,
          body: body,
        );
    final response = await request();
    final data = await _handleResponse(response, retry: request);
    return Streak.fromJson(data);
  }
}
