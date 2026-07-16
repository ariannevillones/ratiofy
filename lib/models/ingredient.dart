import '../utils/units.dart';

/// Represents a single ingredient line item within a [Recipe].
class Ingredient {
  final String id;
  final int refNumber;
  String name;
  double quantity;
  String unit;

  /// Optional. When null, no cost has been entered and no "new est. cost"
  /// figure is calculated or displayed for this ingredient.
  double? cost;

  /// Whether this ingredient is included when "Calculate" is pressed.
  /// Defaults to true (checked) — Calculate scales the whole recipe by
  /// default; uncheck an ingredient to exclude it (e.g. "salt to taste").
  bool includeInCalculation;

  /// Results of the most recent calculation. Null until the user has
  /// pressed Calculate at least once.
  double? newQuantity;
  double? newCost;

  /// Free-text value for the domain's optional extra field (e.g. CAS
  /// Number for Chemical, INCI Name for Cosmetics). See
  /// [DomainDef.extraFieldLabel]. Empty when unused or not applicable to
  /// the recipe's current domain.
  String extraField;

  Ingredient({
    required this.id,
    required this.refNumber,
    required this.name,
    required this.quantity,
    required this.unit,
    this.cost,
    this.includeInCalculation = true,
    this.newQuantity,
    this.newCost,
    this.extraField = '',
  });

  Ingredient copyWith({String? id, int? refNumber}) {
    return Ingredient(
      id: id ?? this.id,
      refNumber: refNumber ?? this.refNumber,
      name: name,
      quantity: quantity,
      unit: unit,
      cost: cost,
      includeInCalculation: includeInCalculation,
      newQuantity: newQuantity,
      newCost: newCost,
      extraField: extraField,
    );
  }

  /// Name to use anywhere it's *displayed* (dropdowns, export text, etc.)
  /// rather than edited. Falls back to a generic label when the user
  /// hasn't typed a name yet, since the name field itself is left blank
  /// (with a hint) rather than pre-filled — there's nothing to delete.
  String get displayName => name.trim().isEmpty ? 'Unnamed ingredient' : name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'refNumber': refNumber,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'cost': cost,
        'includeInCalculation': includeInCalculation,
        'newQuantity': newQuantity,
        'newCost': newCost,
        'extraField': extraField,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      refNumber: json['refNumber'] as int,
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? Units.defaultUnit,
      cost: (json['cost'] as num?)?.toDouble(),
      includeInCalculation: json['includeInCalculation'] as bool? ?? true,
      newQuantity: (json['newQuantity'] as num?)?.toDouble(),
      newCost: (json['newCost'] as num?)?.toDouble(),
      extraField: json['extraField'] as String? ?? '',
    );
  }
}
