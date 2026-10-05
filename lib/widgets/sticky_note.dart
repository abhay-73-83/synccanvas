import 'package:flutter/material.dart';
import '../models/canvas_item.dart';

/// Reusable widget for rendering Sticky Note items on the canvas with edit and delete capabilities.
class StickyNoteWidget extends StatelessWidget {
  final CanvasItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const StickyNoteWidget({
    super.key,
    required this.item,
    this.onDelete,
    this.onEdit,
  });

  Color _parseColor(String colorString) {
    try {
      final hex = colorString.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      return const Color(0xFFFFEB3B); // Default sticky yellow
    } catch (_) {
      return const Color(0xFFFFEB3B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _parseColor(item.color);

    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.note_alt_outlined,
                size: 16,
                color: Colors.black54,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    GestureDetector(
                      onTap: onEdit,
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ),
                  if (onEdit != null && onDelete != null)
                    const SizedBox(width: 8),
                  if (onDelete != null)
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.black45,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GestureDetector(
              onDoubleTap: onEdit,
              child: SingleChildScrollView(
                child: Text(
                  item.content.isEmpty ? 'Sticky Note' : item.content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
