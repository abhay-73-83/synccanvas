import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for capturing RepaintBoundary canvas elements, saving as PNG, and sharing.
class ExportService {
  /// Captures the widget tree under [boundaryKey] as a PNG file, saves it to
  /// temporary disk storage, and triggers the device Share sheet via share_plus.
  Future<bool> exportAndShareCanvas({
    required GlobalKey boundaryKey,
    required String roomName,
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('ExportService: RenderRepaintBoundary object not found.');
        return false;
      }

      // 1. Render boundary to Image at high pixel density
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('ExportService: Error converting image to PNG byte data.');
        return false;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2. Save PNG bytes to local temporary file
      final tempDir = await getTemporaryDirectory();
      final sanitizedName =
          roomName.replaceAll(RegExp(r'[^\w\s]+'), '_').trim();
      final fileName =
          'SyncCanvas_${sanitizedName.isEmpty ? "Canvas" : sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // 3. Share via share_plus XFile
      final xFile = XFile(filePath, mimeType: 'image/png');
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xFile],
        text: 'Canvas exported from SyncCanvas: $roomName',
        subject: 'Canvas Export - $roomName',
      );

      return true;
    } catch (e) {
      debugPrint('ExportService: Error exporting canvas PNG: $e');
      return false;
    }
  }
}
