// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String? userName;
  static String? userRole;
  static bool isLoggedIn = false;

  // 앱 켤 때 저장된 로그인 정보 불러오기
  static Future<void> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    userName = prefs.getString('userName');
    userRole = prefs.getString('userRole');
  }

  // 로그인 성공 시 정보 저장하기
  static Future<void> saveAuth(String name, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userName', name);
    await prefs.setString('userRole', role);
    isLoggedIn = true;
    userName = name;
    userRole = role;
  }

  // 로그아웃
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    isLoggedIn = false;
    userName = null;
    userRole = null;
  }
}