import '../utils/units.dart';

/// A single reusable ingredient definition within a [PresetGroup] — e.g.
/// "Garlic" defaulting to "3 cloves". These are templates: adding one to a
/// recipe copies its values into a fresh [Ingredient] there.
class PresetIngredient {
  final String id;
  String name;
  String unit;
  double quantity;
  double? cost;

  PresetIngredient({
    required this.id,
    required this.name,
    this.unit = Units.defaultUnit,
    this.quantity = 0,
    this.cost,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'cost': cost,
      };

  factory PresetIngredient.fromJson(Map<String, dynamic> json) {
    return PresetIngredient(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? Units.defaultUnit,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble(),
    );
  }
}

/// A user-defined, named group of preset ingredients (e.g. "Filipino
/// Savory Staples") that's available across every recipe, so the user
/// doesn't have to retype the same ingredients each time.
class PresetGroup {
  final String id;
  String label;
  final List<PresetIngredient> ingredients;

  /// Optional domain (see `Domains`) this group is scoped to — e.g. a
  /// "Common Skincare Ingredients" group tagged 'cosmetics' only shows up
  /// when adding ingredients to a Cosmetics recipe. Null means "available
  /// for every domain" (the default for user-created groups and the
  /// always-present Ungrouped group).
  String? domainId;

  PresetGroup({
    required this.id,
    required this.label,
    List<PresetIngredient>? ingredients,
    this.domainId,
  }) : ingredients = ingredients ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'domainId': domainId,
      };

  factory PresetGroup.fromJson(Map<String, dynamic> json) {
    return PresetGroup(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Untitled group',
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => PresetIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      domainId: json['domainId'] as String?,
    );
  }
}
