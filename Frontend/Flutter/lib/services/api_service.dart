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
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
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

  Future<List<dynamic>> _handleListResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
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
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
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
    final response = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return User.fromJson(data);
  }

  Future<User> updateMe(Map<String, dynamic> updates) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/users/me'),
      headers: _headers,
      body: jsonEncode(updates),
    );
    final data = await _handleResponse(response);
    return User.fromJson(data);
  }

  // ── Plans ────────────────────────────────────────────────────────────────

  Future<List<PlanSummary>> listPlans() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/plans'),
      headers: _headers,
    );
    final data = await _handleListResponse(response);
    return data
        .map((p) => PlanSummary.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<Plan> getPlan(String planId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/plans/$planId'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return Plan.fromJson(data);
  }

  Future<Plan> createPlan({
    required String skillName,
    String? description,
    required int daysPerWeek,
    required int minutesPerDay,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/plans'),
      headers: _headers,
      body: jsonEncode({
        'skill_name': skillName,
        if (description != null) 'description': description,
        'success_levels': {
          'should_know': [],
          'might_know': [],
          'should_know_next': [],
        },
        'days_per_week': daysPerWeek,
        'minutes_per_day': minutesPerDay,
      }),
    );
    final data = await _handleResponse(response);
    return Plan.fromJson(data);
  }

  Future<void> deletePlan(String planId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/plans/$planId'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      await _handleResponse(response);
    }
  }

  Future<Plan> editNode(
    String planId,
    String nodeId,
    Map<String, dynamic> changes,
  ) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/plans/$planId/nodes/$nodeId'),
      headers: _headers,
      body: jsonEncode(changes),
    );
    final data = await _handleResponse(response);
    return Plan.fromJson(data);
  }

  Future<Plan> switchBranch(String planId, String branchId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/plans/$planId/switch-branch'),
      headers: _headers,
      body: jsonEncode({'branch_id': branchId}),
    );
    final data = await _handleResponse(response);
    return Plan.fromJson(data);
  }

  Future<Map<String, dynamic>> logProgress(
    String planId,
    String nodeId, {
    required String status,
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/plans/$planId/nodes/$nodeId/progress'),
      headers: _headers,
      body: jsonEncode({
        'status': status,
        if (note != null) 'note': note,
      }),
    );
    return _handleResponse(response);
  }

  // ── Conversations ────────────────────────────────────────────────────────

  Future<Conversation> createConversation({String? planId}) async {
    final uri = planId != null
        ? Uri.parse('$_baseUrl/conversations?plan_id=$planId')
        : Uri.parse('$_baseUrl/conversations');
    final response = await http.post(uri, headers: _headers);
    final data = await _handleResponse(response);
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
    final response = await http.get(uri, headers: _headers);
    final data = await _handleListResponse(response);
    return data
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<Conversation> sendMessage(
    String conversationId, {
    required String content,
    String role = 'user',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/conversations/$conversationId/messages'),
      headers: _headers,
      body: jsonEncode({
        'role': role,
        'content': content,
      }),
    );
    final data = await _handleResponse(response);
    return Conversation.fromJson(data);
  }

  // ── Friends ─────────────────────────────────────────────────────────────

  Future<String> getMyFriendCode() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/friends/code'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return data['friend_code'] as String;
  }

  Future<List<Map<String, dynamic>>> listFriends() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/friends'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return (data['friends'] as List<dynamic>)
        .map((f) => f as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> addFriend(String friendCode) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/friends/add'),
      headers: _headers,
      body: jsonEncode({'friend_code': friendCode}),
    );
    return _handleResponse(response);
  }

  Future<void> removeFriend(String userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/friends/$userId'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      await _handleResponse(response);
    }
  }

  // ── Streaks ──────────────────────────────────────────────────────────────

  Future<UserStats> getMyStats() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/streaks/me/stats'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return UserStats.fromJson(data);
  }

  Future<Streak> getMyStreak() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/streaks/me'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return Streak.fromJson(data);
  }

  Future<Streak> checkIn({
    required String planId,
    required String nodeId,
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/streaks/check-in'),
      headers: _headers,
      body: jsonEncode({
        'plan_id': planId,
        'node_id': nodeId,
        if (note != null) 'note': note,
      }),
    );
    final data = await _handleResponse(response);
    return Streak.fromJson(data);
  }
}
