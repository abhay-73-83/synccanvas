import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/canvas_item.dart';
import '../services/firestore_service.dart';

/// Provider for managing real-time canvas items state and persistence.
class CanvasProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<CanvasItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<CanvasItem>>? _canvasSubscription;
  String? _currentRoomCode;

  /// Unmodifiable view of active canvas items.
  List<CanvasItem> get items => List.unmodifiable(_items);

  /// Loading state indicator.
  bool get isLoading => _isLoading;

  /// Error message string, or null if healthy.
  String? get errorMessage => _errorMessage;

  /// Currently active room code being watched.
  String? get currentRoomCode => _currentRoomCode;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clears current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Listens to real-time updates for canvas items in a given room.
  void startListeningToCanvas(String roomCode) {
    if (_currentRoomCode == roomCode && _canvasSubscription != null) {
      return;
    }

    stopListening();
    _currentRoomCode = roomCode;
    _setLoading(true);

    _canvasSubscription = _firestoreService
        .watchCanvasItems(roomCode: roomCode)
        .listen(
      (newItems) {
        _items = newItems;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _setError('Canvas sync error: $error');
        _setLoading(false);
      },
    );
  }

  /// Cancels the real-time stream subscription and resets canvas state.
  void stopListening() {
    _canvasSubscription?.cancel();
    _canvasSubscription = null;
    _currentRoomCode = null;
    _items = [];
    notifyListeners();
  }

  /// Adds a new canvas item to Firestore.
  Future<CanvasItem?> addItem({
    required String roomCode,
    required CanvasItem item,
  }) async {
    try {
      final createdItem = await _firestoreService.addCanvasItem(
        roomCode: roomCode,
        item: item,
      );
      if (createdItem == null) {
        _setError('Failed to add canvas item.');
      }
      return createdItem;
    } catch (e) {
      _setError('Error adding canvas item: $e');
      return null;
    }
  }

  /// Updates an existing canvas item in Firestore.
  Future<bool> updateItem({
    required String roomCode,
    required CanvasItem item,
  }) async {
    try {
      final success = await _firestoreService.updateCanvasItem(
        roomCode: roomCode,
        item: item,
      );
      if (!success) {
        _setError('Failed to update canvas item.');
      }
      return success;
    } catch (e) {
      _setError('Error updating canvas item: $e');
      return false;
    }
  }

  /// Updates only the position (x, y) of a canvas item.
  Future<bool> updateItemPosition({
    required String roomCode,
    required String itemId,
    required double x,
    required double y,
  }) async {
    try {
      final index = _items.indexWhere((i) => i.id == itemId);
      if (index == -1) return false;

      final currentItem = _items[index];
      final updatedItem = currentItem.copyWith(x: x, y: y);

      return await updateItem(roomCode: roomCode, item: updatedItem);
    } catch (e) {
      _setError('Error updating item position: $e');
      return false;
    }
  }

  /// Deletes a canvas item by ID from Firestore.
  Future<bool> deleteItem({
    required String roomCode,
    required String itemId,
  }) async {
    try {
      final success = await _firestoreService.deleteCanvasItem(
        roomCode: roomCode,
        itemId: itemId,
      );
      if (!success) {
        _setError('Failed to delete canvas item.');
      }
      return success;
    } catch (e) {
      _setError('Error deleting canvas item: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _canvasSubscription?.cancel();
    super.dispose();
  }
}
