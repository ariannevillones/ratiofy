/// Static app metadata shown in the dashboard header and Settings > About.
/// Keep [version] in sync with pubspec.yaml's `version:` field when
/// cutting a new release.
class AppInfo {
  static const String name = 'Ratiofy';
  static const String version = '1.0.0';

  /// Short enough to sit on one line under the app name — in the
  /// dashboard's app bar and the About section.
  static const String tagline = 'Scale by ratio — recipes, batches & formulas.';

  static const String description =
      'Ratiofy keeps every ingredient proportional when you change one '
      'quantity — pick a reference ingredient (or a target batch total) '
      'and everything else scales with it.\n\n'
      'Organize what you make into domains — Food, Chemical, Cosmetics, or '
      'your own custom categories — each with its own default unit, '
      'optional extra field (like a CAS number or INCI name), and common '
      'ingredient presets. Track batch yield and cost per unit, convert '
      'between compatible units, and keep notes or instructions alongside '
      'every recipe.';
}
