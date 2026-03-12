// lib/providers/auth_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum AuthState { idle, loading, authenticated, error }

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  AuthState _state = AuthState.idle;
  String _errorMessage = '';

  UserModel? get user => _user;
  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.login(email, password);

      if (response['success'] == true) {
        _user = UserModel.fromJson(response['data']);
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Login failed';
        _state = AuthState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print("LOGIN ERROR: $e");
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _user = null;
    _state = AuthState.idle;
    _errorMessage = '';
    notifyListeners();
  }
}