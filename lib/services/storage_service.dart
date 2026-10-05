import 'package:shared_preferences/shared_preferences.dart';

/// Centralized local storage service wrapping SharedPreferences.
/// Handles display name, recent room codes, and last opened room state.
class StorageService {
  static const String _keyDisplayName = 'display_name';
  static const String _keyRecentRooms = 'recent_rooms';
  static const String _keyLastOpenedRoom = 'last_opened_room';

  // ================= DISPLAY NAME =================

  /// Saves the user's display name to SharedPreferences.
  Future<void> saveDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, name.trim());
  }

  /// Retrieves the saved display name, or null if not set.
  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyDisplayName);
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return null;
  }

  /// Clears the saved display name.
  Future<void> clearDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDisplayName);
  }

  // ================= RECENT ROOMS =================

  /// Adds a room code to the list of recently visited rooms (up to 10 rooms).
  Future<void> saveRecentRoom(String roomCode) async {
    final cleanCode = roomCode.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    List<String> rooms = prefs.getStringList(_keyRecentRooms) ?? [];
    rooms.remove(cleanCode);
    rooms.insert(0, cleanCode);
    if (rooms.length > 10) {
      rooms = rooms.sublist(0, 10);
    }
    await prefs.setStringList(_keyRecentRooms, rooms);
  }

  /// Gets the list of recently visited room codes.
  Future<List<String>> getRecentRooms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRecentRooms) ?? [];
  }

  /// Removes a room code from the recent rooms list (e.g. if room is deleted/missing).
  Future<void> removeRecentRoom(String roomCode) async {
    final cleanCode = roomCode.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    List<String> rooms = prefs.getStringList(_keyRecentRooms) ?? [];
    rooms.remove(cleanCode);
    await prefs.setStringList(_keyRecentRooms, rooms);
  }

  // ================= LAST OPENED ROOM =================

  /// Saves the last opened room code.
  Future<void> saveLastOpenedRoom(String roomCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastOpenedRoom, roomCode.trim().toUpperCase());
  }

  /// Gets the last opened room code.
  Future<String?> getLastOpenedRoom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastOpenedRoom);
  }

  /// Clears the last opened room code.
  Future<void> clearLastOpenedRoom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastOpenedRoom);
  }
}
