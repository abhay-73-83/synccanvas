import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for uploading media files to Firebase Storage.
class StorageUploadService {
  final FirebaseStorage _storage;

  StorageUploadService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Uploads image raw bytes to Firebase Storage under rooms/{roomCode}/images/{fileName}.
  /// Cross-platform compatible (Android, iOS, Web, Desktop).
  Future<String?> uploadRoomImageBytes({
    required String roomCode,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('rooms')
          .child(roomCode)
          .child('images')
          .child(fileName);

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint(
          'StorageUploadService: Error uploading image bytes ($roomCode): $e');
      return null;
    }
  }
}
