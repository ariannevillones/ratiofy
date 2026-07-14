import 'package:flutter/material.dart';

import '../utils/domains.dart';
import '../utils/units.dart';

/// A user-created domain (category) beyond the built-in set in [Domains] —
/// e.g. a hobbyist might add "Candles" or "Aquarium Mix". Icon and color
/// are stored as JSON-friendly primitives (a key into
/// [Domains.iconChoices], and a packed ARGB int) rather than [IconData] /
/// [Color] directly.
class CustomDomain {
  final String id;
  String name;
  String iconKey;
  int colorValue;
  String defaultUnit;
  bool costVisible;
  String extraFieldLabel;

  CustomDomain({
    required this.id,
    required this.name,
    this.iconKey = Domains.defaultIconKey,
    int? colorValue,
    this.defaultUnit = Units.defaultUnit,
    this.costVisible = true,
    this.extraFieldLabel = '',
  }) : colorValue = colorValue ?? Domains.defaultColor.toARGB32();

  DomainDef toDomainDef() => DomainDef(
        id: id,
        name: name,
        icon: Domains.iconForKey(iconKey),
        color: Color(colorValue),
        exampleName: 'e.g. My $name item',
        defaultUnit: defaultUnit,
        costVisible: costVisible,
        extraFieldLabel: extraFieldLabel,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'defaultUnit': defaultUnit,
        'costVisible': costVisible,
        'extraFieldLabel': extraFieldLabel,
      };

  factory CustomDomain.fromJson(Map<String, dynamic> json) {
    return CustomDomain(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled domain',
      iconKey: json['iconKey'] as String? ?? Domains.defaultIconKey,
      colorValue: json['colorValue'] as int?,
      defaultUnit: json['defaultUnit'] as String? ?? Units.defaultUnit,
      costVisible: json['costVisible'] as bool? ?? true,
      extraFieldLabel: json['extraFieldLabel'] as String? ?? '',
    );
  }
}
