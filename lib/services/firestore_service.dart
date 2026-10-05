import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/canvas_item.dart';
import '../models/room.dart';

/// Firestore service for managing canvas rooms and real-time canvas items.
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _roomsRef =>
      _firestore.collection('rooms');

  CollectionReference<Map<String, dynamic>> _canvasItemsRef(String roomCode) =>
      _roomsRef.doc(roomCode).collection('canvasItems');

  // ================= ROOM OPERATIONS =================

  /// Creates a new room document in Firestore using roomCode as the document ID.
  Future<Room?> createRoom({
    required String roomName,
    required String roomCode,
    required String createdBy,
    required String createdByName,
  }) async {
    try {
      final now = DateTime.now();
      final expireAt = now.add(const Duration(hours: 24));

      final docRef = _roomsRef.doc(roomCode);
      final roomData = {
        'roomName': roomName,
        'roomCode': roomCode,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(expireAt),
        'participantCount': 1,
      };

      await docRef.set(roomData);

      return Room(
        id: roomCode,
        roomName: roomName,
        roomCode: roomCode,
        createdBy: createdBy,
        createdByName: createdByName,
        createdAt: now,
        expireAt: expireAt,
        participantCount: 1,
      );
    } catch (e) {
      debugPrint('FirestoreService: Error creating room ($roomCode): $e');
      return null;
    }
  }

  /// Retrieves a room document by its unique room code.
  Future<Room?> getRoomByCode(String roomCode) async {
    try {
      final doc = await _roomsRef.doc(roomCode).get();
      if (doc.exists && doc.data() != null) {
        return Room.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('FirestoreService: Error fetching room ($roomCode): $e');
      return null;
    }
  }

  /// Increments participant count atomically in Firestore.
  Future<bool> incrementParticipantCount(String roomCode) async {
    try {
      await _roomsRef.doc(roomCode).update({
        'participantCount': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      debugPrint(
          'FirestoreService: Error incrementing participant count ($roomCode): $e');
      return false;
    }
  }

  /// Decrements participant count atomically in Firestore.
  Future<bool> decrementParticipantCount(String roomCode) async {
    try {
      await _roomsRef.doc(roomCode).update({
        'participantCount': FieldValue.increment(-1),
      });
      return true;
    } catch (e) {
      debugPrint(
          'FirestoreService: Error decrementing participant count ($roomCode): $e');
      return false;
    }
  }

  /// Attempts to join a room by roomCode: verifies existence, expiration, and increments participant count.
  Future<Room?> joinRoom(String roomCode) async {
    try {
      final room = await getRoomByCode(roomCode);
      if (room == null || room.isExpired) {
        return null;
      }
      await incrementParticipantCount(roomCode);
      return room.copyWith(participantCount: room.participantCount + 1);
    } catch (e) {
      debugPrint('FirestoreService: Error joining room ($roomCode): $e');
      return null;
    }
  }

  /// Deletes a room document by room code.
  Future<bool> deleteRoom(String roomCode) async {
    try {
      await _roomsRef.doc(roomCode).delete();
      return true;
    } catch (e) {
      debugPrint('FirestoreService: Error deleting room ($roomCode): $e');
      return false;
    }
  }

  /// Updates the participant count for a given room.
  Future<bool> updateParticipantCount(String roomCode, int count) async {
    try {
      await _roomsRef.doc(roomCode).update({
        'participantCount': count,
      });
      return true;
    } catch (e) {
      debugPrint(
          'FirestoreService: Error updating participant count ($roomCode): $e');
      return false;
    }
  }

  /// Real-time stream to observe changes for a specific room.
  Stream<Room?> watchRoom(String roomCode) {
    return _roomsRef.doc(roomCode).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return Room.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    }).handleError((error) {
      debugPrint('FirestoreService: Error in watchRoom ($roomCode): $error');
      return null;
    });
  }

  // ================= CANVAS ITEM OPERATIONS =================

  /// Adds a new canvas item to rooms/{roomCode}/canvasItems subcollection.
  Future<CanvasItem?> addCanvasItem({
    required String roomCode,
    required CanvasItem item,
  }) async {
    try {
      final colRef = _canvasItemsRef(roomCode);
      final docRef = item.id.isNotEmpty ? colRef.doc(item.id) : colRef.doc();

      final data = item.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data);

      return item.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('FirestoreService: Error adding canvas item ($roomCode): $e');
      return null;
    }
  }

  /// Updates an existing canvas item under rooms/{roomCode}/canvasItems/{itemId}.
  Future<bool> updateCanvasItem({
    required String roomCode,
    required CanvasItem item,
  }) async {
    try {
      final docRef = _canvasItemsRef(roomCode).doc(item.id);
      final data = item.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.update(data);
      return true;
    } catch (e) {
      debugPrint(
          'FirestoreService: Error updating canvas item ($roomCode/${item.id}): $e');
      return false;
    }
  }

  /// Efficiently updates only position (x, y) coordinates of a canvas item.
  Future<bool> updateItemPosition({
    required String roomCode,
    required String itemId,
    required double x,
    required double y,
  }) async {
    try {
      await _canvasItemsRef(roomCode).doc(itemId).update({
        'x': x,
        'y': y,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint(
          'FirestoreService: Error updating item position ($roomCode/$itemId): $e');
      return false;
    }
  }

  /// Deletes a canvas item document under rooms/{roomCode}/canvasItems/{itemId}.
  Future<bool> deleteCanvasItem({
    required String roomCode,
    required String itemId,
  }) async {
    try {
      await _canvasItemsRef(roomCode).doc(itemId).delete();
      return true;
    } catch (e) {
      debugPrint(
          'FirestoreService: Error deleting canvas item ($roomCode/$itemId): $e');
      return false;
    }
  }

  /// One-time fetch of all canvas items in a room.
  Future<List<CanvasItem>> getCanvasItems({required String roomCode}) async {
    try {
      final snapshot = await _canvasItemsRef(roomCode).get();
      final items = snapshot.docs
          .map((doc) => CanvasItem.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (e) {
      debugPrint(
          'FirestoreService: Error fetching canvas items ($roomCode): $e');
      return [];
    }
  }

  /// Real-time stream of all canvas items in a room using snapshots().
  Stream<List<CanvasItem>> watchCanvasItems({required String roomCode}) {
    return _canvasItemsRef(roomCode).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CanvasItem.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    }).handleError((error) {
      debugPrint(
          'FirestoreService: Error in watchCanvasItems ($roomCode): $error');
      return <CanvasItem>[];
    });
  }
}
