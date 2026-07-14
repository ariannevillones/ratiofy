import 'package:flutter/material.dart';

/// Renders a photo from a blob/network URL (used on Flutter Web, where
/// image_picker returns a blob: URL rather than a filesystem path).
Widget buildImageFromPath(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    path,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => const Center(
      child: Icon(Icons.broken_image_outlined),
    ),
  );
}
