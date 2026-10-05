import 'package:flutter/material.dart';
import '../models/canvas_item.dart';

/// Reusable widget for rendering Text card elements on the canvas with edit & delete support.
class TextCardWidget extends StatelessWidget {
  final CanvasItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onOptions;

  const TextCardWidget({
    super.key,
    required this.item,
    this.onDelete,
    this.onEdit,
    this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(2, 3),
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
                Icons.text_fields_rounded,
                size: 16,
                color: Colors.deepPurple,
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
                        color: Colors.grey,
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
                        color: Colors.grey,
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
              onLongPress: onOptions,
              child: SingleChildScrollView(
                child: Text(
                  item.content.isEmpty ? 'Sample Text' : item.content,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
