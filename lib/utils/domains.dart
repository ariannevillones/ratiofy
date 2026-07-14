import 'package:flutter/material.dart';

import 'units.dart';

/// Describes one category a recipe/formulation can belong to — e.g. Food,
/// Chemical, Cosmetics. Built-in domains are hardcoded here; user-created
/// custom domains (see [DomainProvider]) reuse the same shape but pick
/// their icon/color from [Domains.iconChoices]/[Domains.colorChoices] so
/// they stay JSON-serializable.
class DomainDef {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  /// Shown as the hint in the "New Recipe" name field when this domain is
  /// selected, so the field feels tailored rather than always food-themed.
  final String exampleName;

  /// Unit newly-added blank ingredients in a recipe of this domain start
  /// with — e.g. a Cosmetics domain might default to 'g' while a Food
  /// domain defaults to 'piece'.
  final String defaultUnit;

  /// Whether the Cost field is shown on ingredients in this domain. Some
  /// domains (e.g. a lab formulation) may care only about ratios, not price.
  final bool costVisible;

  /// Label for an extra free-text field shown on ingredients in this
  /// domain — e.g. "CAS Number" for Chemical, "INCI Name" for Cosmetics.
  /// Empty means the domain has no extra field.
  final String extraFieldLabel;

  bool get hasExtraField => extraFieldLabel.isNotEmpty;

  const DomainDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.exampleName,
    this.defaultUnit = Units.defaultUnit,
    this.costVisible = true,
    this.extraFieldLabel = '',
  });
}

/// Container + on-container color pair for rendering a domain's icon
/// badge, derived from its seed [DomainDef.color] so custom domains with
/// arbitrary colors still get legible contrast in both light and dark mode.
class DomainPalette {
  final Color container;
  final Color onContainer;
  const DomainPalette(this.container, this.onContainer);
}

extension DomainPaletteX on DomainDef {
  DomainPalette paletteFor(Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    final saturation = hsl.saturation.clamp(0.35, 0.85);
    final isDark = brightness == Brightness.dark;
    final container = hsl
        .withSaturation(saturation)
        .withLightness(isDark ? 0.26 : 0.88)
        .toColor();
    final onContainer = hsl
        .withSaturation(saturation)
        .withLightness(isDark ? 0.84 : 0.32)
        .toColor();
    return DomainPalette(container, onContainer);
  }
}

/// Central catalog of domains: the fixed built-in set plus lookup helpers
/// that also consider user-defined custom domains.
class Domains {
  /// Domain assigned to recipes that predate this feature (no domainId in
  /// their saved JSON) and to new recipes unless the user picks another.
  static const String defaultId = 'food';

  static const List<DomainDef> builtIn = [
    DomainDef(
      id: 'food',
      name: 'Food',
      icon: Icons.ramen_dining_outlined,
      color: Color(0xFFE1662F),
      exampleName: 'e.g. Chocolate Chip Cookies',
    ),
    DomainDef(
      id: 'chemical',
      name: 'Chemical',
      icon: Icons.science_outlined,
      color: Color(0xFF2E7DD1),
      exampleName: 'e.g. Sodium Bicarbonate Solution',
      defaultUnit: 'g',
      extraFieldLabel: 'CAS Number',
    ),
    DomainDef(
      id: 'cosmetics',
      name: 'Cosmetics',
      icon: Icons.spa_outlined,
      color: Color(0xFFD1408E),
      exampleName: 'e.g. Whipped Body Butter',
      defaultUnit: 'g',
      extraFieldLabel: 'INCI Name',
    ),
    DomainDef(
      id: 'other',
      name: 'Other',
      icon: Icons.category_outlined,
      color: Color(0xFF6B6B6B),
      exampleName: 'e.g. Custom Mix',
    ),
  ];

  /// Curated icon set custom domains can pick from, keyed by a stable
  /// string so the choice can round-trip through JSON.
  static const Map<String, IconData> iconChoices = {
    'science': Icons.science_outlined,
    'biotech': Icons.biotech_outlined,
    'spa': Icons.spa_outlined,
    'construction': Icons.construction_outlined,
    'palette': Icons.palette_outlined,
    'pets': Icons.pets_outlined,
    'local_florist': Icons.local_florist_outlined,
    'cleaning_services': Icons.cleaning_services_outlined,
    'liquor': Icons.liquor_outlined,
    'category': Icons.category_outlined,
  };

  static const String defaultIconKey = 'category';

  static IconData iconForKey(String key) =>
      iconChoices[key] ?? iconChoices[defaultIconKey]!;

  /// Curated color swatches custom domains can pick from.
  static const List<Color> colorChoices = [
    Color(0xFFE1662F), // orange
    Color(0xFF2E7DD1), // blue
    Color(0xFFD1408E), // pink
    Color(0xFF3FA34D), // green
    Color(0xFF8A5CE0), // purple
    Color(0xFFD1AC2E), // gold
    Color(0xFF2EB6B0), // teal
    Color(0xFFD1482E), // red
    Color(0xFF5C6BC0), // indigo
    Color(0xFF6B6B6B), // grey
  ];

  static const Color defaultColor = Color(0xFF6B6B6B);

  /// Resolves a domainId to its [DomainDef], checking built-ins first, then
  /// [customDomains]. Falls back to the "Other" built-in if the id is
  /// unknown (e.g. its custom domain was since deleted).
  static DomainDef resolve(String domainId, List<DomainDef> customDomains) {
    for (final d in builtIn) {
      if (d.id == domainId) return d;
    }
    for (final d in customDomains) {
      if (d.id == domainId) return d;
    }
    return builtIn.last;
  }
}
