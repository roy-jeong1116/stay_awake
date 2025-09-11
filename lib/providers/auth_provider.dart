import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _currentUser;

  // 테스트용 더미 계정들
  final Map<String, String> _dummyAccounts = {
    'test@example.com': 'password123',
    'user@test.com': '123456',
    'admin@admin.com': 'admin123',
  };

  bool get isLoggedIn => _isLoggedIn;
  String? get currentUser => _currentUser;

  // 로그인 함수
  bool login(String email, String password) {
    if (_dummyAccounts.containsKey(email) && _dummyAccounts[email] == password) {
      _isLoggedIn = true;
      _currentUser = email;
      notifyListeners();
      return true;
    }
    return false;
  }

  // 회원가입 함수 (간단한 더미 구현)
  bool register(String email, String password, String confirmPassword) {
    if (password != confirmPassword) {
      return false;
    }

    if (_dummyAccounts.containsKey(email)) {
      return false; // 이미 존재하는 계정
    }

    if (email.isNotEmpty && password.length >= 6) {
      _dummyAccounts[email] = password;
      return true;
    }
    return false;
  }

  // 로그아웃 함수
  void logout() {
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();
  }

  // 이메일 유효성 검사
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
