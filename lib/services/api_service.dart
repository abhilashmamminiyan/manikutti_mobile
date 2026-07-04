import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  final _secureStorage = const FlutterSecureStorage();
  
  static const String _defaultBaseUrl = 'http://localhost:3000'; // Default for local run. Can change in Settings.
  
  ApiService._init();

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_base_url') ?? _defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
  }

  Future<void> saveSessionToken(String token) async {
    await _secureStorage.write(key: 'session_token', value: token);
  }

  Future<String?> getSessionToken() async {
    return await _secureStorage.read(key: 'session_token');
  }

  Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  Future<void> clearAuth() async {
    await _secureStorage.delete(key: 'session_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('family_code');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getSessionToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- Auth Flow ---
  Future<String?> sendOTP(String email) async {
    final baseUrl = await getBaseUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['token']; // Returns the verification token
      } else {
        throw Exception(body['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> verifyOTP(String email, String otp, String verificationToken) async {
    final baseUrl = await getBaseUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'token': verificationToken,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        await saveSessionToken(body['sessionToken']);
        await saveUserEmail(email);
        return true;
      } else {
        throw Exception(body['error'] ?? 'OTP verification failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Family Membership check & Info ---
  Future<Map<String, dynamic>?> getFamilyInfo() async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/family'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['familyCode'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('family_code', body['familyCode']);
        }
        return body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getCachedFamilyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('family_code');
  }

  // --- Transactions Sheet Access ---
  Future<List<dynamic>> fetchTransactions(String sheetName) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/expense?sheetName=$sheetName'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['expenses'] ?? [];
      } else {
        throw Exception('Failed to fetch expenses: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> createTransaction({
    required String sheetName,
    required Map<String, dynamic> expense,
    String? familyCode,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/expense'),
        headers: headers,
        body: jsonEncode({
          'sheetName': sheetName,
          'expense': expense,
          if (familyCode != null) 'familyCode': familyCode,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> acceptInvitation(String token) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/family'),
        headers: headers,
        body: jsonEncode({
          'action': 'accept',
          'token': token,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
