import 'package:flutter/material.dart';

/// The Ratiofy brand lockup: the icon badge (navy square, crop-bracket
/// frame, ratio-dot colon) next to the "ratio"/"fy" wordmark, set in
/// Space Grotesk (bundled locally in assets/fonts/ so it renders offline
/// on first launch, rather than fetched at runtime via google_fonts).
///
/// The wordmark's "ratio" half follows [ColorScheme.onSurface] rather than
/// the brand navy (#16224D) so it stays legible on dark surfaces; "fy"
/// keeps the fixed brand blue (#3AC1F2) as an accent.
class RatiofyLogo extends StatelessWidget {
  const RatiofyLogo({super.key, this.iconSize = 32, this.fontSize = 24});

  final double iconSize;
  final double fontSize;

  /// Shared with main.dart's startup precache call, so the icon is
  /// already decoded by the time the loading screen (which shows this
  /// widget) first paints, instead of racing provider startup and
  /// sometimes losing.
  static const iconAssetPath = 'assets/branding/ratiofy_icon.png';

  static const brandBlue = Color(0xFF3AC1F2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The source PNG is 1024x1024 (a launcher-icon leftover); decoding it
    // at full resolution just to display at [iconSize] wastes memory and
    // some decode time, so cacheWidth/Height decode at the actual display
    // size instead. The loading screen's minimum display duration (see
    // _AppStartupGate in main.dart) is what actually guarantees the icon
    // is visible by the time the app transitions away.
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cachePixelSize = (iconSize * devicePixelRatio).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(iconSize * 0.22),
          child: Image.asset(
            iconAssetPath,
            width: iconSize,
            height: iconSize,
            cacheWidth: cachePixelSize,
            cacheHeight: cachePixelSize,
          ),
        ),
        SizedBox(width: iconSize * 0.28),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'ratio',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontVariations: const [FontVariation('wght', 700)],
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                  height: 1,
                ),
              ),
              TextSpan(
                text: 'fy',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontVariations: const [FontVariation('wght', 700)],
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: brandBlue,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
