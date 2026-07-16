/// Multiplicative unit conversion between compatible units of measure —
/// e.g. grams <-> kilograms, cups <-> milliliters, or hours <-> seconds.
/// Count units ('piece', 'bundle', 'pack') and Temperature ('°C', '°F',
/// which need an offset, not a multiplier) are intentionally left
/// unconvertible.
enum _Quantity { volume, mass, length, time }

class UnitConversion {
  static const Map<String, _Quantity> _quantityOf = {
    'ml': _Quantity.volume,
    'l': _Quantity.volume,
    'tsp': _Quantity.volume,
    'tbsp': _Quantity.volume,
    'cup': _Quantity.volume,
    'pt': _Quantity.volume,
    'gal': _Quantity.volume,
    'mg': _Quantity.mass,
    'g': _Quantity.mass,
    'kg': _Quantity.mass,
    'oz': _Quantity.mass,
    'lb': _Quantity.mass,
    'mm': _Quantity.length,
    'cm': _Quantity.length,
    'm': _Quantity.length,
    'in': _Quantity.length,
    'ft': _Quantity.length,
    'ms': _Quantity.time,
    's': _Quantity.time,
    'h': _Quantity.time,
    'd': _Quantity.time,
  };

  /// Factor to multiply a unit's value by to express it in its category's
  /// base unit (liter for volume, gram for mass, meter for length).
  static const Map<String, double> _factorToBase = {
    'ml': 0.001,
    'l': 1,
    'tsp': 0.00492892,
    'tbsp': 0.0147868,
    'cup': 0.236588,
    'pt': 0.473176,
    'gal': 3.78541,
    'mg': 0.001,
    'g': 1,
    'kg': 1000,
    'oz': 28.3495,
    'lb': 453.592,
    'mm': 0.001,
    'cm': 0.01,
    'm': 1,
    'in': 0.0254,
    'ft': 0.3048,
    'ms': 0.001,
    's': 1,
    'h': 3600,
    'd': 86400,
  };

  static bool isConvertible(String unit) => _quantityOf.containsKey(unit);

  static bool canConvert(String from, String to) {
    final q = _quantityOf[from];
    return q != null && q == _quantityOf[to];
  }

  /// Converts [value] from [from] to [to]. Returns null if the two units
  /// aren't the same physical quantity (e.g. mass vs. volume).
  static double? convert(double value, String from, String to) {
    if (from == to) return value;
    if (!canConvert(from, to)) return null;
    final baseValue = value * _factorToBase[from]!;
    return baseValue / _factorToBase[to]!;
  }

  /// Other units [unit] can convert to/from (same physical quantity,
  /// excluding itself) — for populating a "convert to" picker.
  static List<String> compatibleUnits(String unit) {
    final quantity = _quantityOf[unit];
    if (quantity == null) return const [];
    return [
      for (final entry in _quantityOf.entries)
        if (entry.value == quantity && entry.key != unit) entry.key,
    ];
  }
}
