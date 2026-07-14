/// Central place defining the units of measurement available in the
/// "Unit" dropdown, grouped by category for readability.
class UnitGroup {
  final String category;
  final List<String> units;
  const UnitGroup(this.category, this.units);
}

class Units {
  /// Default unit for a newly created ingredient — grams, the most common
  /// unit across food, chemical, and cosmetic formulations.
  static const String defaultUnit = 'g';

  static const List<UnitGroup> groups = [
    UnitGroup('Count', ['piece', 'bundle', 'pack']),
    UnitGroup('Volume (SI)', ['ml', 'l']),
    UnitGroup('Volume (Imperial)', ['tsp', 'tbsp', 'cup', 'pt', 'gal']),
    UnitGroup('Mass (SI)', ['mg', 'g', 'kg']),
    UnitGroup('Mass (Imperial)', ['oz', 'lb']),
    UnitGroup('Length (SI)', ['mm', 'cm', 'm']),
    UnitGroup('Length (Imperial)', ['in', 'ft']),
    UnitGroup('Temperature', ['°C', '°F']),
  ];

  /// Flat list of every selectable unit, in display order.
  static List<String> get all =>
      groups.expand((g) => g.units).toList(growable: false);
}
