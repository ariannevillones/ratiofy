import 'package:flutter/material.dart';

/// The stylized "ratiofy" wordmark: bold colored "ratio", a small-over-big
/// dot pair standing in for the ratio colon, then a thin "fy".
class RatiofyWordmark extends StatelessWidget {
  const RatiofyWordmark({super.key, this.fontSize = 24});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ratio',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
            height: 1,
          ),
        ),
        SizedBox(width: fontSize * 0.1),
        _RatioDots(size: fontSize, color: dotColor),
        SizedBox(width: fontSize * 0.1),
        Text(
          'fy',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
            color: dotColor,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _RatioDots extends StatelessWidget {
  const _RatioDots({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final smallDot = size * 0.14;
    final bigDot = size * 0.26;

    return SizedBox(
      height: size * 0.72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Dot(diameter: smallDot, color: color),
          _Dot(diameter: bigDot, color: color),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
