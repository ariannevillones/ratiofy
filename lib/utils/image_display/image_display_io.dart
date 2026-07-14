import 'dart:io';

import 'package:flutter/material.dart';

/// Renders a photo from a local file path (used on iOS, Android, desktop).
Widget buildImageFromPath(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.file(
    File(path),
    fit: fit,
    errorBuilder: (context, error, stackTrace) => const Center(
      child: Icon(Icons.broken_image_outlined),
    ),
  );
}
