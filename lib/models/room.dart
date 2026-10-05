import 'package:cloud_firestore/cloud_firestore.dart';

/// Room data model representing a collaborative canvas room in Firestore.
class Room {
  final String id;
  final String roomName;
  final String roomCode;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime expireAt;
  final int participantCount;

  Room({
    required this.id,
    required this.roomName,
    required this.roomCode,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    DateTime? expireAt,
    this.participantCount = 1,
  }) : expireAt = expireAt ?? createdAt.add(const Duration(hours: 24));

  /// Returns whether the room has reached or passed its 24-hour expiration time.
  bool get isExpired => !DateTime.now().isBefore(expireAt);

  /// Factory to construct a Room model from a Firestore document map.
  factory Room.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime parsedExpireAt;
    if (map['expireAt'] is Timestamp) {
      parsedExpireAt = (map['expireAt'] as Timestamp).toDate();
    } else if (map['expireAt'] is int) {
      parsedExpireAt = DateTime.fromMillisecondsSinceEpoch(map['expireAt'] as int);
    } else {
      // Safe fallback for old rooms created before expireAt feature was added
      parsedExpireAt = parsedCreatedAt.add(const Duration(hours: 24));
    }

    return Room(
      id: id,
      roomName: map['roomName'] as String? ?? 'Untitled Room',
      roomCode: map['roomCode'] as String? ?? id,
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? 'Anonymous',
      createdAt: parsedCreatedAt,
      expireAt: parsedExpireAt,
      participantCount: (map['participantCount'] as num?)?.toInt() ?? 1,
    );
  }

  /// Converts the Room model to a JSON map for Firestore persistence.
  Map<String, dynamic> toMap() {
    return {
      'roomName': roomName,
      'roomCode': roomCode,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'expireAt': Timestamp.fromDate(expireAt),
      'participantCount': participantCount,
    };
  }

  /// CopyWith helper method to clone a Room instance with updated fields.
  Room copyWith({
    String? id,
    String? roomName,
    String? roomCode,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? expireAt,
    int? participantCount,
  }) {
    return Room(
      id: id ?? this.id,
      roomName: roomName ?? this.roomName,
      roomCode: roomCode ?? this.roomCode,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      expireAt: expireAt ?? this.expireAt,
      participantCount: participantCount ?? this.participantCount,
    );
  }
}

