import 'dart:math';

/// Utility class for generating clean, unambiguous room codes.
class RoomCodeGenerator {
  // Exclude easily confused characters (0, O, 1, I, L)
  static const String _allowedChars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// Generates an uppercase 6-character room code.
  static String generate({int length = 6}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _allowedChars[random.nextInt(_allowedChars.length)],
    ).join();
  }
}
