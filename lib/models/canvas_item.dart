import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported types for items rendered on the collaborative canvas.
enum CanvasItemType {
  note,
  text,
  image,
  link;

  String toValue() => name;

  static CanvasItemType fromString(String? value) {
    return CanvasItemType.values.firstWhere(
      (e) => e.name.toLowerCase() == value?.toLowerCase(),
      orElse: () => CanvasItemType.note,
    );
  }
}

/// Data model representing an individual element (note, text, image, link) on a canvas.
class CanvasItem {
  final String id;
  final CanvasItemType type;
  final String content;
  final double x;
  final double y;
  final double width;
  final double height;
  final String color;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  CanvasItem({
    required this.id,
    required this.type,
    required this.content,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deserializes a Firestore document map into a CanvasItem instance.
  factory CanvasItem.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic field) {
      if (field is Timestamp) {
        return field.toDate();
      } else if (field is int) {
        return DateTime.fromMillisecondsSinceEpoch(field);
      }
      return DateTime.now();
    }

    return CanvasItem(
      id: id,
      type: CanvasItemType.fromString(map['type'] as String?),
      content: map['content'] as String? ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 200.0,
      height: (map['height'] as num?)?.toDouble() ?? 150.0,
      color: map['color'] as String? ?? '#FFEB3B',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  /// Serializes the CanvasItem model to a Map for Firestore persistence.
  Map<String, dynamic> toMap() {
    return {
      'type': type.toValue(),
      'content': content,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'color': color,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Helper copyWith method to clone a CanvasItem with modified properties.
  CanvasItem copyWith({
    String? id,
    CanvasItemType? type,
    String? content,
    double? x,
    double? y,
    double? width,
    double? height,
    String? color,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CanvasItem(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      color: color ?? this.color,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
