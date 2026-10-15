import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  final _secureStorage = const FlutterSecureStorage();

  static const String _defaultBaseUrl =
      'https://manikutti.vercel.app'; // Default to Vercel production deployment.

  ApiService._init();

  Future<String> getBaseUrl() async {
    if (!kDebugMode) {
      return _defaultBaseUrl;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_base_url') ?? _defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    String formattedUrl = url.trim();
    if (formattedUrl.isNotEmpty &&
        !formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      final isLocal =
          formattedUrl.contains('localhost') ||
          formattedUrl.startsWith('192.168.') ||
          formattedUrl.startsWith('10.') ||
          formattedUrl.startsWith('127.0.0.1');
      formattedUrl = isLocal ? 'http://$formattedUrl' : 'https://$formattedUrl';
    }
    await prefs.setString('api_base_url', formattedUrl);
  }

  Future<void> saveSessionToken(String token) async {
    try {
      await _secureStorage.write(key: 'session_token', value: token);
    } catch (e) {
      print('Error writing session token to secure storage: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', token);
  }

  Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('session_token');
    if (tokenFromPrefs != null && tokenFromPrefs.isNotEmpty) {
      return tokenFromPrefs;
    }
    try {
      final token = await _secureStorage.read(key: 'session_token');
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      print('Error reading session token from secure storage: $e');
    }
    return null;
  }

  Future<void> saveUserEmail(String email) async {
    try {
      await _secureStorage.write(key: 'user_email', value: email);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final emailFromPrefs = prefs.getString('user_email');
    if (emailFromPrefs != null && emailFromPrefs.isNotEmpty) {
      return emailFromPrefs;
    }
    try {
      return await _secureStorage.read(key: 'user_email');
    } catch (_) {
      return null;
    }
  }

  Future<void> savePin(String pin) async {
    try {
      await _secureStorage.write(key: 'app_lock_pin', value: pin);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lock_pin', pin);
    await prefs.setBool('app_lock_enabled', true);
  }

  Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pinFromPrefs = prefs.getString('app_lock_pin');
    if (pinFromPrefs != null && pinFromPrefs.length == 4) {
      return pinFromPrefs;
    }
    try {
      return await _secureStorage.read(key: 'app_lock_pin');
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final lockEnabled = prefs.getBool('app_lock_enabled') ?? true;
    if (!lockEnabled) return false;
    final pin = await getPin();
    return pin != null && pin.length == 4;
  }

  Future<void> clearPin() async {
    try {
      await _secureStorage.delete(key: 'app_lock_pin');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_lock_pin');
    await prefs.setBool('app_lock_enabled', false);
  }

  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: 'session_token');
      await _secureStorage.delete(key: 'user_email');
      await _secureStorage.delete(key: 'app_lock_pin');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('session_token');
    await prefs.remove('family_code');
    await prefs.remove('app_lock_pin');
    await prefs.remove('app_lock_enabled');
  }

  Future<void> clearAuth() async {
    await clearSession();
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
        body: jsonEncode({'email': email, 'clientType': 'mobile'}),
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

  Future<bool> verifyOTP(
    String email,
    String otp,
    String verificationToken,
  ) async {
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

  Future<bool> batchCreateTransactions({
    required String sheetName,
    required List<Map<String, dynamic>> expenses,
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
          'expenses': expenses,
          if (familyCode != null) 'familyCode': familyCode,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error in batchCreateTransactions: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> parseBankStatement({
    required List<int> fileBytes,
    required String fileName,
    String? mimeType,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final base64Content = base64Encode(fileBytes);
      final response = await http.post(
        Uri.parse('$baseUrl/api/statement/parse'),
        headers: headers,
        body: jsonEncode({
          'fileBase64': base64Content,
          'fileName': fileName,
          'mimeType': mimeType ??
              (fileName.toLowerCase().endsWith('.pdf')
                  ? 'application/pdf'
                  : 'text/csv'),
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'transactions': body['transactions'] ?? [],
          'count': body['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': body['error'] ?? 'Failed to parse statement',
          'transactions': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'transactions': [],
      };
    }
  }

  Future<bool> acceptInvitation(String token) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/family'),
        headers: headers,
        body: jsonEncode({'action': 'accept', 'token': token}),
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

  Future<bool> updateMember({
    required String targetEmail,
    String? nickname,
    double? baseSalary,
    double? currentSalary,
    double? monthlyIncome,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/family'),
        headers: headers,
        body: jsonEncode({
          'action': 'updateMember',
          'targetEmail': targetEmail,
          if (nickname != null) 'nickname': nickname,
          if (baseSalary != null) 'baseSalary': baseSalary,
          if (currentSalary != null) 'currentSalary': currentSalary,
          if (monthlyIncome != null) 'monthlyIncome': monthlyIncome,
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

  Future<List<dynamic>> fetchMonthlyExpenses(String familyCode) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/monthly?familyCode=$familyCode'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['items'] ?? [];
      } else {
        throw Exception(
          'Failed to fetch monthly expenses: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> markMonthlyExpensePaid(int id, String paidDate) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/sheets/monthly'),
        headers: headers,
        body: jsonEncode({'id': id, 'paidDate': paidDate}),
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

  Future<List<dynamic>> fetchNotifications(String familyCode) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/notifications?familyCode=$familyCode'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['notifications'] ?? [];
      } else {
        throw Exception(
          'Failed to fetch notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Personal Utilities ---
  Future<List<dynamic>> fetchUtilities() async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/utilities'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['items'] ?? [];
      } else {
        throw Exception('Failed to fetch utilities: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> addUtility(Map<String, dynamic> utility) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/utilities'),
        headers: headers,
        body: jsonEncode(utility),
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

  Future<bool> markUtilityPaid(int id, String paidDate, bool logExpense) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/sheets/utilities'),
        headers: headers,
        body: jsonEncode({
          'id': id,
          'paidDate': paidDate,
          'logExpense': logExpense,
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

  // --- EMI & Loans Access ---
  Future<List<dynamic>> fetchEmiBills(String familyCode) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/emi?familyCode=$familyCode'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['items'] ?? [];
      } else {
        throw Exception('Failed to fetch EMI bills: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> createEmiBill(Map<String, dynamic> data) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/emi'),
        headers: headers,
        body: jsonEncode(data),
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

  Future<bool> updateEmiBillStatus({
    required int id,
    required String status,
    required int paidMonths,
    required String dueDate,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/sheets/emi'),
        headers: headers,
        body: jsonEncode({
          'id': id,
          'status': status,
          'paidMonths': paidMonths,
          'dueDate': dueDate,
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

  Future<Map<String, dynamic>> fetchLoansData(String familyCode) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/loans?familyCode=$familyCode'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body;
      } else {
        throw Exception('Failed to fetch loans data: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> createLoan({
    required String loanName,
    required double amount,
    required double monthlyEMI,
    required String assignedTo,
    required String familyCode,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/loans'),
        headers: headers,
        body: jsonEncode({
          'action': 'addLoan',
          'loanName': loanName,
          'amount': amount,
          'monthlyEMI': monthlyEMI,
          'assignedTo': assignedTo,
          'familyCode': familyCode,
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

  Future<bool> createLoanExpense({
    required String loanName,
    required String familyCode,
    required Map<String, dynamic> expense,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/loans'),
        headers: headers,
        body: jsonEncode({
          'action': 'addLoanExpense',
          'loanName': loanName,
          'familyCode': familyCode,
          'expense': expense,
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

  // --- Home Loan Access ---
  Future<List<dynamic>> fetchHomeLoanHistory(String familyCode) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/home-loan?familyCode=$familyCode'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['items'] ?? [];
      } else {
        throw Exception(
          'Failed to fetch home loan history: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> addHomeLoanRepayment({
    required String date,
    required double totalPayment,
    required double principal,
    required double interest,
    required double balance,
    required String familyCode,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/home-loan'),
        headers: headers,
        body: jsonEncode({
          'date': date,
          'totalPayment': totalPayment,
          'principal': principal,
          'interest': interest,
          'balance': balance,
          'familyCode': familyCode,
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

  Future<bool> updateHomeLoanRepayment({
    required int id,
    required String date,
    required double totalPayment,
    required double principal,
    required double interest,
    required double balance,
    required String familyCode,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/sheets/home-loan'),
        headers: headers,
        body: jsonEncode({
          'id': id,
          'date': date,
          'totalPayment': totalPayment,
          'principal': principal,
          'interest': interest,
          'balance': balance,
          'familyCode': familyCode,
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

  Future<bool> deleteHomeLoanRepayment(int id) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/sheets/home-loan?id=$id'),
        headers: headers,
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

  // --- Mobile Recharges API ---

  Future<List<dynamic>> fetchMobileRecharges() async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sheets/mobile-recharges'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['items'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addMobileRecharge(Map<String, dynamic> recharge) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sheets/mobile-recharges'),
        headers: headers,
        body: jsonEncode(recharge),
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

  Future<bool> updateMobileRecharge(Map<String, dynamic> recharge) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/sheets/mobile-recharges'),
        headers: headers,
        body: jsonEncode(recharge),
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

  Future<bool> deleteMobileRecharge(int id) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/sheets/mobile-recharges?id=$id'),
        headers: headers,
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

  /// Fetches AI Financial Advisor advice in Malayalam based on user expenses
  Future<Map<String, dynamic>?> getAiExpenseAdvice({
    String sheetName = 'Personal_Expenses',
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ai/expense-advisor?sheetName=$sheetName'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
      return {
        'success': false,
        'error': 'സെർവർ പിശക് സംഭവിച്ചു (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'error': 'ഇന്റർനെറ്റ് കണക്ഷൻ പരിശോധിക്കുക.'};
    }
  }
}
