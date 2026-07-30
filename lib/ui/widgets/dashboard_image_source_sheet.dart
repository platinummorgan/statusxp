import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

Future<ImageSource?> chooseDashboardImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: const Color(0xFF0A0E27),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose Image Source',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optimal: 1080x1920 (9:16 portrait)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(
              Icons.photo_library,
              color: CyberpunkTheme.neonPurple,
            ),
            title: const Text('Gallery', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: CyberpunkTheme.neonCyan,
              ),
              title: const Text(
                'Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
        ],
      ),
    ),
  );
}
