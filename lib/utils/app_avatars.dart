import 'package:flutter/material.dart';
import 'package:splitwise/utils/constants.dart';

/// App-wide avatar definitions.
/// The [photoUrl] field on UserModel stores `"avatar:<id>"` to use a built-in avatar.
/// Otherwise it falls back to initials.
class AppAvatars {
  AppAvatars._();

  static const List<Map<String, String>> avatars = [
    {'id': 'boy_1',  'asset': 'assets/avatars/boy_1.png',  'label': 'Boy 1',  'gender': 'male'},
    {'id': 'boy_2',  'asset': 'assets/avatars/boy_2.png',  'label': 'Boy 2',  'gender': 'male'},
    {'id': 'boy_3',  'asset': 'assets/avatars/boy_3.png',  'label': 'Boy 3',  'gender': 'male'},
    {'id': 'boy_4',  'asset': 'assets/avatars/boy_4.png',  'label': 'Boy 4',  'gender': 'male'},
    {'id': 'girl_1', 'asset': 'assets/avatars/girl_1.png', 'label': 'Girl 1', 'gender': 'female'},
    {'id': 'girl_2', 'asset': 'assets/avatars/girl_2.png', 'label': 'Girl 2', 'gender': 'female'},
    {'id': 'girl_3', 'asset': 'assets/avatars/girl_3.png', 'label': 'Girl 3', 'gender': 'female'},
    {'id': 'girl_4', 'asset': 'assets/avatars/girl_4.png', 'label': 'Girl 4', 'gender': 'female'},
  ];

  /// Returns the asset path for a given avatar id, or null if not found.
  static String? assetForId(String id) {
    final match = avatars.where((a) => a['id'] == id);
    return match.isNotEmpty ? match.first['asset'] : null;
  }

  /// Returns true if a [photoUrl] represents a built-in avatar.
  static bool isAvatar(String? photoUrl) =>
      photoUrl != null && photoUrl.startsWith('avatar:');

  /// Extracts the avatar id from a [photoUrl] like `"avatar:boy_1"`.
  static String? avatarIdFromUrl(String? photoUrl) {
    if (!isAvatar(photoUrl)) return null;
    return photoUrl!.substring('avatar:'.length);
  }

  /// Encodes an avatar id as a photoUrl value.
  static String encodeAvatarUrl(String avatarId) => 'avatar:$avatarId';

  /// Builds a [CircleAvatar] that renders either:
  /// - The built-in image avatar if [photoUrl] starts with `"avatar:"`
  /// - Initials fallback otherwise
  static Widget buildAvatar({
    required String? photoUrl,
    required String displayName,
    double radius = 24,
    Color? backgroundColor,
    TextStyle? initialsStyle,
  }) {
    final bg = backgroundColor ?? AppConstants.accentTeal.withOpacity(0.18);
    if (isAvatar(photoUrl)) {
      final id = avatarIdFromUrl(photoUrl)!;
      final asset = assetForId(id);
      if (asset != null) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: bg,
          backgroundImage: AssetImage(asset),
        );
      }
    }
    // Initials fallback
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initial,
        style: initialsStyle ??
            TextStyle(
              color: AppConstants.accentTeal,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.75,
            ),
      ),
    );
  }

  /// Shows a bottom sheet that lets the user pick one of the built-in avatars.
  /// Returns the selected avatar id, or null if dismissed.
  static Future<String?> showAvatarPicker(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose Avatar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 16,
                alignment: WrapAlignment.start,
                children: avatars.map((a) {
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, a['id']),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              a['asset']!,
                              width: 56, height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a['label']!,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
