import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

/// Provider for managing current user state, display name, and auth details.
class UserProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();

  String? _displayName;
  String? _userId;
  bool _isInitialized = false;

  String? get displayName => _displayName;
  String? get userId => _userId;
  bool get isInitialized => _isInitialized;
  bool get hasDisplayName => _displayName != null && _displayName!.isNotEmpty;

  /// Initializes authentication and fetches the local display name.
  Future<void> initializeUser() async {
    final user = await _authService.ensureAuthenticated();
    _userId = user?.uid;
    _displayName = await _storageService.getDisplayName();
    _isInitialized = true;
    notifyListeners();
  }

  /// Updates and saves the display name locally.
  Future<void> setDisplayName(String name) async {
    final trimmedName = name.trim();
    await _storageService.saveDisplayName(trimmedName);
    _displayName = trimmedName;
    notifyListeners();
  }
}
