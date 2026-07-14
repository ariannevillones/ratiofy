/// Picks the correct `buildImageFromPath(path, {fit})` implementation for
/// the current platform at compile time, so we never `import 'dart:io'`
/// (which fails to compile on web) or `dart:html` on native targets.
library;

export 'image_display/image_display_stub.dart'
    if (dart.library.io) 'image_display/image_display_io.dart'
    if (dart.library.html) 'image_display/image_display_web.dart';
