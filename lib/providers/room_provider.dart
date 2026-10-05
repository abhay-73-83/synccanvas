import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/room_code_generator.dart';

/// Provider for managing active room state, creation, joining, and real-time syncing.
class RoomProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  Room? _currentRoom;
  List<String> _recentRooms = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<Room?>? _roomSubscription;

  RoomProvider() {
    loadRecentRooms();
  }

  Room? get currentRoom => _currentRoom;
  List<String> get recentRooms => List.unmodifiable(_recentRooms);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clears any existing error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Loads recent room codes from local storage and notifies listeners.
  Future<void> loadRecentRooms() async {
    _recentRooms = await _storageService.getRecentRooms();
    notifyListeners();
  }

  /// Removes a recent room code from local storage and updates the state.
  Future<void> removeRecentRoom(String roomCode) async {
    await _storageService.removeRecentRoom(roomCode);
    await loadRecentRooms();
  }

  /// Creates a new room with a generated code, saves to Firestore and local storage.
  Future<Room?> createRoom({
    required String roomName,
    required String createdBy,
    required String createdByName,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      String roomCode = '';
      bool isUnique = false;
      int attempts = 0;

      while (!isUnique && attempts < 5) {
        attempts++;
        roomCode = RoomCodeGenerator.generate(length: 6);
        final existing = await _firestoreService.getRoomByCode(roomCode);
        if (existing == null) {
          isUnique = true;
        }
      }

      if (!isUnique) {
        _setError('Failed to generate a unique room code. Please try again.');
        _setLoading(false);
        return null;
      }

      final room = await _firestoreService.createRoom(
        roomName: roomName,
        roomCode: roomCode,
        createdBy: createdBy,
        createdByName: createdByName,
      );

      if (room == null) {
        _setError('Could not create room in database. Check your connection.');
        _setLoading(false);
        return null;
      }

      await _storageService.saveRecentRoom(roomCode);
      await loadRecentRooms();
      _currentRoom = room;
      watchRoom(roomCode);
      _setLoading(false);
      return room;
    } catch (e) {
      _setError('Error creating room: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Joins an existing room by its room code if not expired.
  Future<Room?> joinRoom(String roomCode) async {
    _setLoading(true);
    _setError(null);

    final cleanCode = roomCode.trim().toUpperCase();
    if (cleanCode.length != 6) {
      _setError('Room code must be exactly 6 characters.');
      _setLoading(false);
      return null;
    }

    try {
      final room = await _firestoreService.getRoomByCode(cleanCode);

      if (room == null) {
        _setError('Room not found. Please check the room code.');
        _setLoading(false);
        return null;
      }

      if (room.isExpired) {
        _setError('This room has expired.');
        _setLoading(false);
        return null;
      }

      await _firestoreService.incrementParticipantCount(cleanCode);
      final updatedRoom = room.copyWith(participantCount: room.participantCount + 1);

      await _storageService.saveRecentRoom(cleanCode);
      await loadRecentRooms();
      _currentRoom = updatedRoom;
      watchRoom(cleanCode);
      _setLoading(false);
      return updatedRoom;
    } catch (e) {
      _setError('Error joining room: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Subscribes to real-time updates for a specific room.
  void watchRoom(String roomCode) {
    _roomSubscription?.cancel();
    _roomSubscription = _firestoreService.watchRoom(roomCode).listen(
      (updatedRoom) {
        _currentRoom = updatedRoom;
        notifyListeners();
      },
      onError: (error) {
        _setError('Room update error: $error');
      },
    );
  }

  /// Leaves the current active room and atomically decrements participant count.
  Future<void> leaveRoom() async {
    if (_currentRoom != null) {
      final roomCode = _currentRoom!.roomCode;
      await _firestoreService.decrementParticipantCount(roomCode);
    }
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _currentRoom = null;
    notifyListeners();
  }

  /// Deletes a room document by code.
  Future<bool> deleteRoom(String roomCode) async {
    _setLoading(true);
    try {
      final success = await _firestoreService.deleteRoom(roomCode);
      if (success) {
        await _storageService.removeRecentRoom(roomCode);
        await loadRecentRooms();
        if (_currentRoom?.roomCode == roomCode) {
          _roomSubscription?.cancel();
          _roomSubscription = null;
          _currentRoom = null;
        }
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError('Error deleting room: $e');
      _setLoading(false);
      return false;
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }
}
