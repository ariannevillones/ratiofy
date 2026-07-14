import 'package:flutter/material.dart';

import '../utils/domains.dart';

/// A small circular swatch showing a domain's icon tinted with its color,
/// used anywhere domains are listed compactly — filter chips, dropdown
/// items, and the Settings domain list — so categories stay visually
/// distinct at a glance.
class DomainIconBadge extends StatelessWidget {
  final DomainDef domain;
  final double size;

  const DomainIconBadge({super.key, required this.domain, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final palette = domain.paletteFor(Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: palette.container),
      alignment: Alignment.center,
      child: Icon(domain.icon, size: size * 0.55, color: palette.onContainer),
    );
  }
}
