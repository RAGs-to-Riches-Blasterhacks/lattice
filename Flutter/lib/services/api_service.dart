import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://localhost:8000/api';

  Future<List<dynamic>> getItems() async {
    final response = await http.get(Uri.parse('$_baseUrl/items'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['items'] as List<dynamic>;
    }
    throw Exception('Failed to load items: ${response.statusCode}');
  }
}
