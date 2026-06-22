import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/crm_model.dart';

class ApiService {
  static const String baseUrl = 'https://agsdemo.in/emapi/public/api';
  
  // Custom User-Agent header to prevent Mod_Security 406 blocks
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static Map<String, String> _authHeaders(String token) {
    return {
      ..._headers,
      'Authorization': 'Bearer $token',
    };
  }

  /// Signup a new user/company
  Future<bool> signup({
    required String companyType,
    required String companyName,
    required String companyMobile,
    required String companyEmail,
  }) async {
    final url = Uri.parse('$baseUrl/signup');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: {
          'enquiry_company_type': companyType,
          'enquiry_company_name': companyName,
          'enquiry_company_mobile': companyMobile,
          'enquiry_company_email': companyEmail,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Signup failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Login and fetch authorization token and user profile
  Future<Map<String, dynamic>> login({
    required String mobile,
    required String password,
    required String deviceId,
  }) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: {
          'mobile': mobile,
          'password': password,
          'device_id': deviceId,
        },
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['code'] == 200) {
        return decoded['data'] as Map<String, dynamic>;
      } else {
        throw Exception(decoded['msg'] ?? 'Login failed. Please verify credentials.');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch leads dashboard and available statuses list
  Future<Map<String, dynamic>> fetchHome(String token) async {
    final url = Uri.parse('$baseUrl/fetch-home');
    try {
      final response = await http.post(
        url,
        headers: _authHeaders(token),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['code'] == 200) {
        final List<dynamic> leadsJson = decoded['data'] ?? [];
        final List<dynamic> statusJson = decoded['status'] ?? [];

        final leads = leadsJson.map((e) => Lead.fromJson(e)).toList();
        final statuses = statusJson.map((e) {
          final statusName = e['companyStatus'].toString();
          return CompanyStatus(id: -1, companyStatus: statusName);
        }).toList();

        return {
          'leads': leads,
          'statuses': statuses,
        };
      } else {
        throw Exception(decoded['msg'] ?? 'Failed to fetch dashboard data.');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch full list of company statuses with official IDs
  Future<List<CompanyStatus>> fetchCompanyStatus(String token) async {
    final url = Uri.parse('$baseUrl/fetch-company-status');
    try {
      final response = await http.post(
        url,
        headers: _authHeaders(token),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['code'] == 200) {
        final List<dynamic> list = decoded['data'] ?? [];
        return list.map((e) => CompanyStatus.fromJson(e)).toList();
      } else {
        throw Exception(decoded['msg'] ?? 'Failed to fetch status list.');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update lead's followup date, time, and status
  Future<bool> updateFollowup({
    required String token,
    required int dataId,
    required String followupDate,
    required String followupTime,
    required String dataStatus,
  }) async {
    final url = Uri.parse('$baseUrl/update-followup');
    try {
      final response = await http.post(
        url,
        headers: _authHeaders(token),
        body: {
          'data_id': dataId.toString(),
          'followup_date': followupDate,
          'followup_time': followupTime,
          'data_status': dataStatus,
        },
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['code'] == 200) {
        return true;
      } else {
        throw Exception(decoded['msg'] ?? 'Failed to update followup.');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch user profile details from backend
  Future<Map<String, dynamic>> fetchProfile(String token) async {
    final url = Uri.parse('$baseUrl/fetch-profile');
    try {
      final response = await http.get(
        url,
        headers: _authHeaders(token),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded is Map && decoded.containsKey('data')) {
        return decoded['data'] as Map<String, dynamic>;
      } else {
        throw Exception(
          decoded is Map && decoded.containsKey('msg')
              ? decoded['msg']
              : 'Failed to fetch profile.',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateProfile({
    required String token,
    required String name,
    required String mobile,
    required String email,
    String? imagePath,
  }) async {
    final url = Uri.parse('$baseUrl/update-profile');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_authHeaders(token));
      
      request.fields['_method'] = 'PUT';
      request.fields['name'] = name;
      request.fields['mobile'] = mobile;
      request.fields['email'] = email;
      
      if (imagePath != null && imagePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('user_image', imagePath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded.containsKey('code') && decoded['code'] != 200) {
            throw Exception(decoded['msg'] ?? 'Failed to update profile.');
          }
          return decoded is Map ? (decoded['data'] as Map<String, dynamic>?) : null;
        }
        return null;
      } else {
        throw Exception('Server error: status code ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete user profile account
  Future<bool> deleteProfile(String token) async {
    final url = Uri.parse('$baseUrl/delete-profile');
    try {
      final response = await http.delete(
        url,
        headers: _authHeaders(token),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (decoded is Map && decoded.containsKey('code') && decoded['code'] != 200) {
          throw Exception(decoded['msg'] ?? 'Failed to delete account.');
        }
        return true;
      } else {
        throw Exception(
          decoded is Map && decoded.containsKey('msg')
              ? decoded['msg']
              : 'Failed to delete account.',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Request forgot password link/recovery
  Future<bool> forgotPassword({
    required String mobile,
    required String email,
  }) async {
    final url = Uri.parse('$baseUrl/forgot-password');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: {
          'mobile': mobile,
          'email': email,
        },
      );

      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (response.statusCode == 200) {
          if (decoded is Map && decoded.containsKey('code') && decoded['code'] != 200) {
            throw Exception(decoded['msg'] ?? 'Failed to request password reset.');
          }
          return true;
        } else {
          throw Exception(
            decoded is Map && decoded.containsKey('msg')
                ? decoded['msg']
                : 'Failed to request password reset.',
          );
        }
      } else {
        if (response.statusCode == 200) {
          return true;
        } else {
          throw Exception('Failed to request password reset (Status: ${response.statusCode}).');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Change user password
  Future<bool> changePassword({
    required String token,
    required String mobile,
    required String oldPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/change-password');
    try {
      final response = await http.post(
        url,
        headers: _authHeaders(token),
        body: {
          'mobile': mobile,
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );

      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (response.statusCode == 200) {
          if (decoded is Map && decoded.containsKey('code') && decoded['code'] != 200) {
            throw Exception(decoded['msg'] ?? 'Failed to change password.');
          }
          return true;
        } else {
          throw Exception(
            decoded is Map && decoded.containsKey('msg')
                ? decoded['msg']
                : 'Failed to change password.',
          );
        }
      } else {
        if (response.statusCode == 200) {
          return true;
        } else {
          throw Exception('Failed to change password (Status: ${response.statusCode}).');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update user's default message on the server
  Future<bool> updateDefaultMessage({
    required String token,
    required String message,
  }) async {
    final url = Uri.parse('$baseUrl/update-default-message');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_authHeaders(token));
      request.fields['user_default_message'] = message;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded.containsKey('code') && decoded['code'] != 200) {
            throw Exception(decoded['msg'] ?? 'Failed to update default message.');
          }
          return true;
        }
        return true;
      } else {
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            throw Exception(
              decoded is Map && decoded.containsKey('msg')
                  ? decoded['msg']
                  : 'Server error: status code ${response.statusCode}',
            );
          } catch (_) {
            throw Exception('Server error: status code ${response.statusCode}');
          }
        }
        throw Exception('Server error: status code ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

