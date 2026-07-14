import 'package:flutter/material.dart';

/// Fallback used only if neither dart:io nor dart:html is available.
/// Should never actually be hit on iOS, Android, web, or desktop.
Widget buildImageFromPath(String path, {BoxFit fit = BoxFit.cover}) {
  return const Center(child: Icon(Icons.image_not_supported_outlined));
}
