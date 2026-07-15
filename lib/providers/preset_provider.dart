import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preset.dart';
import '../utils/units.dart';

/// Manages user-defined groups of preset ingredients. These are global —
/// available from every recipe — and persisted locally.
class PresetProvider extends ChangeNotifier {
  static const _groupsKey = 'presets.groups.v1';
  static const _seededKey = 'presets.hasSeededDefaults.v1';
  static const _seqKey = 'presets.sequenceCounters.v1';

  /// Fixed id (not sequence-generated) for the always-present "Ungrouped"
  /// group, so ingredients can be added without first creating a named
  /// group. Can't be renamed or deleted.
  static const String ungroupedGroupId = 'preset_group_ungrouped';

  final List<PresetGroup> _groups = [];
  int _nextGroupSeq = 1;
  int _nextIngredientSeq = 1;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<PresetGroup> get groups => List.unmodifiable(_groups);

  PresetGroup? getGroup(String groupId) {
    for (final g in _groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final groupsJson = prefs.getString(_groupsKey);
    if (groupsJson != null) {
      try {
        final decoded = jsonDecode(groupsJson) as List<dynamic>;
        _groups
          ..clear()
          ..addAll(decoded
              .map((e) => PresetGroup.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // Corrupt data — start fresh rather than crashing the app.
      }
    }

    final seqJson = prefs.getString(_seqKey);
    if (seqJson != null) {
      try {
        final decoded = jsonDecode(seqJson) as Map<String, dynamic>;
        _nextGroupSeq = decoded['nextGroupSeq'] as int? ?? 1;
        _nextIngredientSeq = decoded['nextIngredientSeq'] as int? ?? 1;
      } catch (_) {
        // ignore, keep defaults
      }
    }

    var needsPersist = _ensureUngroupedGroup();

    // Seed starter groups once, on the very first run, so common
    // ingredients per domain are immediately discoverable. Never re-seeds
    // after that, even if the user deletes them. Ignores the
    // always-present Ungrouped group when deciding whether this is a
    // "fresh" install.
    final hasSeeded = prefs.getBool(_seededKey) ?? false;
    final hasNamedGroups = _groups.any((g) => g.id != ungroupedGroupId);
    if (!hasSeeded && !hasNamedGroups) {
      _groups.addAll([
        _buildSavoryStaplesSeed(),
        _buildBakingStaplesSeed(),
        _buildMeatsSeed(),
        _buildVegetablesSeed(),
        _buildSeafoodSeed(),
        _buildSpicesSeed(),
        _buildHouseholdChemistrySeed(),
        _buildSkincareSeed(),
      ]);
      await prefs.setBool(_seededKey, true);
      needsPersist = true;
    }

    if (needsPersist) await _persist();

    _isLoaded = true;
    notifyListeners();
  }

  /// Inserts the always-present "Ungrouped" group at the front of the list
  /// if it isn't there yet (fresh install, or upgrading from a version
  /// before this feature existed). Returns true if it added the group.
  bool _ensureUngroupedGroup() {
    if (_groups.any((g) => g.id == ungroupedGroupId)) return false;
    _groups.insert(
        0, PresetGroup(id: ungroupedGroupId, label: 'Ungrouped'));
    return true;
  }

  PresetIngredient _seedIngredient(String name,
      {double quantity = 0, String unit = Units.defaultUnit}) {
    return PresetIngredient(
      id: 'preset_ing_${_nextIngredientSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      quantity: quantity,
      unit: unit,
    );
  }

  PresetGroup _seedGroup(String label, {String? domainId}) {
    return PresetGroup(
      id: 'preset_group_${_nextGroupSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      domainId: domainId,
    );
  }

  PresetGroup _buildSavoryStaplesSeed() {
    final group = _seedGroup('Savory Staples', domainId: 'food');
    group.ingredients.addAll([
      _seedIngredient('Onions', quantity: 2, unit: 'piece'),
      _seedIngredient('Garlic', quantity: 5, unit: 'piece'),
      _seedIngredient('Salt', quantity: 1, unit: 'tsp'),
      _seedIngredient('Soy sauce', quantity: 3, unit: 'tbsp'),
      _seedIngredient('Vinegar', quantity: 3, unit: 'tbsp'),
      _seedIngredient('Tomatoes', quantity: 2, unit: 'piece'),
      _seedIngredient('Fish sauce', quantity: 1, unit: 'tbsp'),
    ]);
    return group;
  }

  /// Common vegetables — a general-purpose grocery-list style starter set
  /// for the Food domain.
  PresetGroup _buildVegetablesSeed() {
    final group = _seedGroup('Vegetables', domainId: 'food');
    group.ingredients.addAll([
      _seedIngredient('Potatoes', quantity: 3, unit: 'piece'),
      _seedIngredient('Carrots', quantity: 2, unit: 'piece'),
      _seedIngredient('Onions', quantity: 1, unit: 'piece'),
      _seedIngredient('Garlic', quantity: 3, unit: 'piece'),
      _seedIngredient('Tomatoes', quantity: 2, unit: 'piece'),
      _seedIngredient('Bell pepper', quantity: 1, unit: 'piece'),
      _seedIngredient('Cabbage', quantity: 1, unit: 'piece'),
      _seedIngredient('Broccoli', quantity: 1, unit: 'piece'),
      _seedIngredient('Spinach', quantity: 100, unit: 'g'),
      _seedIngredient('Cucumber', quantity: 1, unit: 'piece'),
    ]);
    return group;
  }

  /// Common seafood — a general-purpose starter set for the Food domain.
  PresetGroup _buildSeafoodSeed() {
    final group = _seedGroup('Seafood', domainId: 'food');
    group.ingredients.addAll([
      _seedIngredient('Shrimp', quantity: 300, unit: 'g'),
      _seedIngredient('Fish fillet', quantity: 300, unit: 'g'),
      _seedIngredient('Salmon', quantity: 300, unit: 'g'),
      _seedIngredient('Tuna', quantity: 200, unit: 'g'),
      _seedIngredient('Squid', quantity: 250, unit: 'g'),
      _seedIngredient('Crab', quantity: 2, unit: 'piece'),
      _seedIngredient('Mussels', quantity: 500, unit: 'g'),
      _seedIngredient('Clams', quantity: 500, unit: 'g'),
    ]);
    return group;
  }

  /// Common spices — a general-purpose starter set for the Food domain.
  PresetGroup _buildSpicesSeed() {
    final group = _seedGroup('Spices', domainId: 'food');
    group.ingredients.addAll([
      _seedIngredient('Black pepper', quantity: 1, unit: 'tsp'),
      _seedIngredient('Paprika', quantity: 1, unit: 'tsp'),
      _seedIngredient('Cumin', quantity: 1, unit: 'tsp'),
      _seedIngredient('Turmeric', quantity: 1, unit: 'tsp'),
      _seedIngredient('Chili powder', quantity: 1, unit: 'tsp'),
      _seedIngredient('Cinnamon', quantity: 1, unit: 'tsp'),
      _seedIngredient('Bay leaves', quantity: 2, unit: 'piece'),
      _seedIngredient('Star anise', quantity: 2, unit: 'piece'),
      _seedIngredient('Ginger', quantity: 1, unit: 'tbsp'),
    ]);
    return group;
  }

  /// Common baking/cooking pantry staples — a broadly-applicable starter
  /// set for the Food domain, independent of cuisine.
  PresetGroup _buildBakingStaplesSeed() {
    final group = _seedGroup('Common Baking Staples', domainId: 'food');
    group.ingredients.addAll([
      _seedIngredient('Flour', quantity: 2, unit: 'cup'),
      _seedIngredient('Sugar', quantity: 1, unit: 'cup'),
      _seedIngredient('Butter', quantity: 0.5, unit: 'cup'),
      _seedIngredient('Eggs', quantity: 2, unit: 'piece'),
      _seedIngredient('Salt', quantity: 1, unit: 'tsp'),
      _seedIngredient('Baking powder', quantity: 1, unit: 'tsp'),
      _seedIngredient('Milk', quantity: 1, unit: 'cup'),
      _seedIngredient('Vanilla extract', quantity: 1, unit: 'tsp'),
      _seedIngredient('Olive oil', quantity: 2, unit: 'tbsp'),
    ]);
    return group;
  }

  /// Common meats used as a recipe's protein base.
  PresetGroup _buildMeatsSeed() {
    final group = _seedGroup('Meats', domainId: 'food');
    group.ingredients.addAll([
      _seedIngredient('Chicken', quantity: 500, unit: 'g'),
      _seedIngredient('Pork', quantity: 500, unit: 'g'),
      _seedIngredient('Beef', quantity: 500, unit: 'g'),
      _seedIngredient('Mutton', quantity: 500, unit: 'g'),
    ]);
    return group;
  }

  /// Common ingredients for DIY household-chemistry formulations (cleaning
  /// mixes, descalers, etc.) — sourced from common natural-cleaning
  /// ingredient lists, not lab-grade reagents.
  PresetGroup _buildHouseholdChemistrySeed() {
    final group =
        _seedGroup('Common Household Chemistry', domainId: 'chemical');
    group.ingredients.addAll([
      _seedIngredient('Baking soda (sodium bicarbonate)',
          quantity: 1, unit: 'cup'),
      _seedIngredient('Citric acid', quantity: 2, unit: 'tbsp'),
      _seedIngredient('White vinegar (acetic acid)',
          quantity: 1, unit: 'cup'),
      _seedIngredient('Isopropyl alcohol', quantity: 1, unit: 'cup'),
      _seedIngredient('Distilled water', quantity: 1, unit: 'l'),
      _seedIngredient('Washing soda (sodium carbonate)',
          quantity: 0.5, unit: 'cup'),
      _seedIngredient('Castile soap', quantity: 2, unit: 'tbsp'),
      _seedIngredient('Hydrogen peroxide', quantity: 0.25, unit: 'cup'),
      _seedIngredient('Salt (sodium chloride)', quantity: 1, unit: 'tbsp'),
    ]);
    return group;
  }

  /// Common ingredients for DIY skincare/cosmetic formulations — sourced
  /// from beginner cosmetic-formulation ingredient guides.
  PresetGroup _buildSkincareSeed() {
    final group = _seedGroup('Common Skincare Ingredients',
        domainId: 'cosmetics');
    group.ingredients.addAll([
      _seedIngredient('Shea butter', quantity: 50, unit: 'g'),
      _seedIngredient('Coconut oil', quantity: 30, unit: 'g'),
      _seedIngredient('Jojoba oil', quantity: 20, unit: 'g'),
      _seedIngredient('Beeswax', quantity: 10, unit: 'g'),
      _seedIngredient('Glycerin', quantity: 5, unit: 'g'),
      _seedIngredient('Emulsifying wax', quantity: 8, unit: 'g'),
      _seedIngredient('Vitamin E oil', quantity: 2, unit: 'g'),
      _seedIngredient('Aloe vera gel', quantity: 20, unit: 'g'),
      _seedIngredient('Citric acid (pH adjuster)', quantity: 1, unit: 'g'),
      _seedIngredient('Lavender essential oil', quantity: 10, unit: 'g'),
    ]);
    return group;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _groupsKey, jsonEncode(_groups.map((g) => g.toJson()).toList()));
    await prefs.setString(
      _seqKey,
      jsonEncode({
        'nextGroupSeq': _nextGroupSeq,
        'nextIngredientSeq': _nextIngredientSeq,
      }),
    );
  }

  // ---------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------

  PresetGroup addGroup(String label, {String? domainId}) {
    final group = PresetGroup(
      id: 'preset_group_${_nextGroupSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      label: label.trim(),
      domainId: domainId,
    );
    _groups.add(group);
    notifyListeners();
    _persist();
    return group;
  }

  /// Updates which domain (if any) a group is scoped to. Pass null for
  /// "available in every domain". No-op for the Ungrouped group.
  void setGroupDomain(String groupId, String? domainId) {
    if (groupId == ungroupedGroupId) return;
    final group = getGroup(groupId);
    if (group == null) return;
    group.domainId = domainId;
    notifyListeners();
    _persist();
  }

  void renameGroup(String groupId, String newLabel) {
    if (groupId == ungroupedGroupId) return;
    final group = getGroup(groupId);
    if (group == null) return;
    group.label = newLabel.trim();
    notifyListeners();
    _persist();
  }

  void deleteGroup(String groupId) {
    if (groupId == ungroupedGroupId) return;
    _groups.removeWhere((g) => g.id == groupId);
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // Preset ingredients
  // ---------------------------------------------------------------------

  void addPresetIngredient(
    String groupId, {
    required String name,
    String unit = Units.defaultUnit,
    double quantity = 0,
    double? cost,
  }) {
    final group = getGroup(groupId);
    if (group == null) return;
    group.ingredients.add(PresetIngredient(
      id: 'preset_ing_${_nextIngredientSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      unit: unit,
      quantity: quantity,
      cost: cost,
    ));
    notifyListeners();
    _persist();
  }

  void updatePresetIngredient(
    String groupId,
    String ingredientId, {
    String? name,
    String? unit,
    double? quantity,
    double? cost,
    bool clearCost = false,
  }) {
    final group = getGroup(groupId);
    if (group == null) return;
    for (final ing in group.ingredients) {
      if (ing.id == ingredientId) {
        if (name != null) ing.name = name.trim();
        if (unit != null) ing.unit = unit;
        if (quantity != null) ing.quantity = quantity;
        if (clearCost) {
          ing.cost = null;
        } else if (cost != null) {
          ing.cost = cost;
        }
        break;
      }
    }
    notifyListeners();
    _persist();
  }

  void deletePresetIngredient(String groupId, String ingredientId) {
    final group = getGroup(groupId);
    if (group == null) return;
    group.ingredients.removeWhere((i) => i.id == ingredientId);
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // Backup / restore
  // ---------------------------------------------------------------------

  Map<String, dynamic> exportAll() => {
        'groups': _groups.map((g) => g.toJson()).toList(),
        'nextGroupSeq': _nextGroupSeq,
        'nextIngredientSeq': _nextIngredientSeq,
      };

  Future<void> importAll(Map<String, dynamic> data) async {
    final decoded = (data['groups'] as List<dynamic>? ?? [])
        .map((e) => PresetGroup.fromJson(e as Map<String, dynamic>))
        .toList();
    _groups
      ..clear()
      ..addAll(decoded);
    _nextGroupSeq = data['nextGroupSeq'] as int? ?? _nextGroupSeq;
    _nextIngredientSeq =
        data['nextIngredientSeq'] as int? ?? _nextIngredientSeq;
    _ensureUngroupedGroup();
    notifyListeners();
    await _persist();
  }
}
