import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class AuthState extends ChangeNotifier {
  // Singleton pattern
  static final AuthState _instance = AuthState._internal();
  factory AuthState() => _instance;
  AuthState._internal();

  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';
  static const String _keyDeviceId = 'auth_device_id';

  String? _token;
  Map<String, dynamic>? _userProfile;
  String? _deviceId;
  bool _isInitialized = false;

  String? get token => _token;
  Map<String, dynamic>? get userProfile => _userProfile;
  String? get deviceId => _deviceId;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// Initialize state by loading saved credentials
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get or generate persistent Device ID
    _deviceId = prefs.getString(_keyDeviceId);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = const Uuid().v4();
      await prefs.setString(_keyDeviceId, _deviceId!);
    }
    
    // 2. Load token and user profile
    _token = prefs.getString(_keyToken);
    final userJsonStr = prefs.getString(_keyUser);
    if (userJsonStr != null) {
      try {
        _userProfile = jsonDecode(userJsonStr) as Map<String, dynamic>;
      } catch (e) {
        _userProfile = null;
      }
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Store login details
  Future<void> saveLogin(String token, Map<String, dynamic> userProfile) async {
    final prefs = await SharedPreferences.getInstance();
    _token = token;
    _userProfile = userProfile;
    
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(userProfile));

    // Update local common message cache if stored on the server
    final defaultMessage = userProfile['user_default_message'];
    await prefs.setString('common_message', (defaultMessage ?? '').toString());
    
    notifyListeners();
  }

  /// Clear login credentials
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _token = null;
    _userProfile = null;
    
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    
    notifyListeners();
  }

  /// Persist status change timestamp
  static Future<void> saveStatusChangeTime(int leadId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // format as "19 Jun 2026, 04:20 PM"
    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    await prefs.setString('status_change_time_$leadId', formattedTime);
    await prefs.setString('status_change_value_$leadId', status);
  }

  /// Retrieve status change timestamp (fallback dynamically to creation date if not modified)
  static Future<String> getStatusChangeTime(int leadId, String dataCreated) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getString('status_change_time_$leadId');
    if (savedTime != null && savedTime.isNotEmpty) {
      return savedTime;
    }
    // Fallback: parse dataCreated (e.g. "2026-03-29") and add dynamic hour offset based on ID
    try {
      final parsedDate = DateTime.parse(dataCreated.trim());
      final withOffset = parsedDate.add(Duration(
        hours: 9 + (leadId % 6), 
        minutes: 10 + (leadId % 45)
      ));
      return DateFormat('dd MMM yyyy, hh:mm a').format(withOffset);
    } catch (_) {
      return '$dataCreated, 10:30 AM';
    }
  }
}
