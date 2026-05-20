import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.userName,
    this.profileImageUrl,
    this.radius = 44,
    this.onTap,
  });

  final String userName;
  final String? profileImageUrl;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = profileImageProvider(profileImageUrl);
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.teal,
        backgroundImage: image,
        child: image == null
            ? Text(
                userName.isEmpty
                    ? 'C'
                    : userName.characters.first.toUpperCase(),
                style: TextStyle(
                  fontSize: radius * 0.72,
                  fontWeight: FontWeight.w900,
                  color: colors.ink,
                ),
              )
            : null,
      ),
    );
  }
}

ImageProvider? profileImageProvider(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final text = value.trim();
  if (text.startsWith('data:image/')) {
    final comma = text.indexOf(',');
    if (comma == -1) return null;
    try {
      return MemoryImage(base64Decode(text.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(text);
}

Future<String?> pickProfileImageDataUrl() async {
  final result = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  return dataUrlFromImageBytes(bytes, file.extension);
}

String dataUrlFromImageBytes(Uint8List bytes, String? extension) {
  final normalized = (extension ?? 'png').toLowerCase();
  final mime = switch (normalized) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
