import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/canvas_item.dart';

/// Reusable widget for rendering Link card elements on the canvas with open link support.
class LinkCardWidget extends StatelessWidget {
  final CanvasItem item;
  final VoidCallback? onDelete;

  const LinkCardWidget({
    super.key,
    required this.item,
    this.onDelete,
  });

  Future<void> _openUrl(BuildContext context) async {
    final urlStr = item.content.trim();
    if (urlStr.isEmpty) return;

    final uri = Uri.parse(urlStr.startsWith('http') ? urlStr : 'https://$urlStr');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlStr')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = item.content.trim();

    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
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
              const Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Link',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
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
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                displayUrl.isEmpty ? 'https://example.com' : displayUrl,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton.icon(
              onPressed: () => _openUrl(context),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open Link', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
