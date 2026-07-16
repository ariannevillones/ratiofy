import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ingredient.dart';
import '../models/preset.dart';
import '../models/recipe.dart';
import '../utils/recipe_templates.dart';
import '../utils/unit_conversion.dart';
import '../utils/units.dart';

/// Result of an attempted ingredient-add, used so the UI can show a
/// meaningful message when the 30-ingredient cap is hit.
enum AddIngredientResult { success, recipeFull }

/// Result of an attempted calculation.
enum CalculateResult {
  success,
  noBaseSelected,
  invalidTargetQuantity,
  baseQuantityIsZero,
  incompatibleUnits,
}

class RecipeProvider extends ChangeNotifier {
  static const _recipesKey = 'recipes.v1';
  static const _seqKey = 'recipes.sequenceCounters.v1';

  /// One-time migration flag: ingredients used to default to unchecked
  /// (excluded from Calculate), which meant Calculate silently did nothing
  /// on recipes nobody had manually checked. Now that new ingredients
  /// default to checked, this flips every already-saved ingredient to
  /// checked too, once, so existing recipes aren't stuck on the old
  /// behavior.
  static const _includeAllMigrationKey = 'recipes.includeAllMigration.v1';

  final List<Recipe> _recipes = [];
  int _nextRecipeSeq = 1;
  int _nextIngredientSeq = 1;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<Recipe> get recipes => List.unmodifiable(_recipes);

  Recipe? getRecipe(String recipeId) {
    for (final r in _recipes) {
      if (r.id == recipeId) return r;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final recipesJson = prefs.getString(_recipesKey);
    if (recipesJson != null) {
      try {
        final decoded = jsonDecode(recipesJson) as List<dynamic>;
        _recipes
          ..clear()
          ..addAll(
              decoded.map((e) => Recipe.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // Corrupt data — start fresh rather than crashing the app.
      }
    }

    final seqJson = prefs.getString(_seqKey);
    if (seqJson != null) {
      try {
        final decoded = jsonDecode(seqJson) as Map<String, dynamic>;
        _nextRecipeSeq = decoded['nextRecipeSeq'] as int? ?? 1;
        _nextIngredientSeq = decoded['nextIngredientSeq'] as int? ?? 1;
      } catch (_) {
        // ignore, keep defaults
      }
    }

    if (!(prefs.getBool(_includeAllMigrationKey) ?? false)) {
      for (final recipe in _recipes) {
        for (final ingredient in recipe.ingredients) {
          ingredient.includeInCalculation = true;
        }
      }
      await prefs.setBool(_includeAllMigrationKey, true);
      if (_recipes.isNotEmpty) await _persist();
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final recipesJson = jsonEncode(_recipes.map((r) => r.toJson()).toList());
    await prefs.setString(_recipesKey, recipesJson);
    await prefs.setString(
      _seqKey,
      jsonEncode({
        'nextRecipeSeq': _nextRecipeSeq,
        'nextIngredientSeq': _nextIngredientSeq,
      }),
    );
  }

  /// Explicitly flushes current state to local storage. Used by the
  /// recipe detail screen's "Save" menu action so the user gets a
  /// definite confirmation, even though changes also auto-save as they
  /// happen.
  Future<void> saveNow() => _persist();

  // ---------------------------------------------------------------------
  // Recipes
  // ---------------------------------------------------------------------

  Recipe addRecipe(String name, {String? domainId}) {
    final recipe = Recipe(
      id: 'recipe_${_nextRecipeSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      domainId: domainId,
    );
    _recipes.add(recipe);
    notifyListeners();
    _persist();
    return recipe;
  }

  /// Creates a new recipe pre-filled from a [RecipeTemplate] — name,
  /// domain, and every ingredient with its default quantity/unit — so the
  /// user can add a common recipe/formula in one tap instead of building
  /// it from scratch. Cost is left blank on every ingredient, matching
  /// how preset ingredients behave.
  Recipe addRecipeFromTemplate(RecipeTemplate template) {
    final recipe = Recipe(
      id: 'recipe_${_nextRecipeSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      name: template.name,
      domainId: template.domainId,
    );
    for (final templateIngredient in template.ingredients) {
      final refNumber = recipe.consumeNextRefNumber();
      recipe.ingredients.add(Ingredient(
        id: 'ing_${_nextIngredientSeq++}_${DateTime.now().microsecondsSinceEpoch}',
        refNumber: refNumber,
        name: templateIngredient.name,
        quantity: templateIngredient.quantity,
        unit: templateIngredient.unit,
      ));
    }
    _recipes.add(recipe);
    notifyListeners();
    _persist();
    return recipe;
  }

  void setRecipeDomain(String recipeId, String domainId) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.domainId = domainId;
    notifyListeners();
    _persist();
  }

  /// Toggles whether [recipeId] is pinned as a favorite — powers the
  /// Dashboard's Favorites carousel.
  void toggleFavorite(String recipeId) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.isFavorite = !recipe.isFavorite;
    notifyListeners();
    _persist();
  }

  void deleteRecipe(String recipeId) {
    _recipes.removeWhere((r) => r.id == recipeId);
    notifyListeners();
    _persist();
  }

  /// Records that the recipe was just opened — powers "Recently opened"
  /// sorting on the dashboard.
  void touchRecipe(String recipeId) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.lastOpenedAt = DateTime.now();
    _persist();
  }

  /// Sets (or clears, by passing nulls) the recipe's batch yield — e.g.
  /// "24 cookies" — used to derive a cost-per-unit summary.
  void setRecipeYield(String recipeId, {double? quantity, String? unit}) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.yieldQuantity = quantity;
    recipe.yieldUnit = unit?.trim() ?? '';
    notifyListeners();
    _persist();
  }

  void renameRecipe(String recipeId, String newName) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.name = newName.trim();
    notifyListeners();
    _persist();
  }

  void updateRecipeNotes(String recipeId, String notes) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.notes = notes;
    notifyListeners();
    _persist();
  }

  /// Creates a copy of [recipeId] — new recipe id, "Copy of ..." name,
  /// and freshly-numbered ingredient copies (quantity/unit/cost/checked
  /// state preserved; calculated results and the manual "Calculate for"
  /// pick are reset).
  Recipe? duplicateRecipe(String recipeId) {
    final source = getRecipe(recipeId);
    if (source == null) return null;

    final newRecipe = Recipe(
      id: 'recipe_${_nextRecipeSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      name: 'Copy of ${source.name}',
      notes: source.notes,
      domainId: source.domainId,
      photoPaths: List<String>.from(source.photoPaths),
    );

    for (final ingredient in source.ingredients) {
      final refNumber = newRecipe.consumeNextRefNumber();
      newRecipe.ingredients.add(Ingredient(
        id: 'ing_${_nextIngredientSeq++}_${DateTime.now().microsecondsSinceEpoch}',
        refNumber: refNumber,
        name: ingredient.name,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        cost: ingredient.cost,
        includeInCalculation: ingredient.includeInCalculation,
      ));
    }

    _recipes.add(newRecipe);
    notifyListeners();
    _persist();
    return newRecipe;
  }

  /// Builds a plain-text summary of a recipe, suitable for copying to the
  /// clipboard or sharing.
  String exportRecipeAsText(String recipeId, {required String currencySymbol}) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return '';

    final buffer = StringBuffer()..writeln(recipe.name);
    if (recipe.notes.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(recipe.notes.trim());
    }
    buffer
      ..writeln()
      ..writeln('Ingredients:');

    for (final ingredient in recipe.ingredients) {
      final qty = _formatNumber(ingredient.quantity);
      final costSuffix = ingredient.cost != null
          ? ', $currencySymbol${ingredient.cost!.toStringAsFixed(2)}'
          : '';
      buffer.writeln(
          '  ${ingredient.displayName}: $qty ${ingredient.unit}$costSuffix');
      if (ingredient.newQuantity != null) {
        final newQty = _formatNumber(ingredient.newQuantity!);
        final newCostSuffix = ingredient.newCost != null
            ? ', $currencySymbol${ingredient.newCost!.toStringAsFixed(2)}'
            : '';
        buffer.writeln('    → new: $newQty ${ingredient.unit}$newCostSuffix');
      }
    }

    return buffer.toString().trimRight();
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  // ---------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------

  /// Adds a photo (by path/URL) to the recipe. Returns false if the
  /// recipe already has the maximum of [Recipe.maxPhotos] photos.
  bool addPhoto(String recipeId, String path) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return false;
    if (recipe.hasMaxPhotos) return false;
    recipe.photoPaths.add(path);
    notifyListeners();
    _persist();
    return true;
  }

  void deletePhoto(String recipeId, String path) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.photoPaths.remove(path);
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // Ingredients
  // ---------------------------------------------------------------------

  /// Adds a blank ingredient. [unit] lets the caller default it to the
  /// recipe's domain's preferred unit (e.g. 'g' for Chemical) instead of
  /// the global default.
  AddIngredientResult addIngredient(String recipeId, {String? unit}) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return AddIngredientResult.recipeFull;
    if (recipe.isFull) return AddIngredientResult.recipeFull;

    final refNumber = recipe.consumeNextRefNumber();
    final ingredient = Ingredient(
      id: 'ing_${_nextIngredientSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      refNumber: refNumber,
      name: '',
      quantity: 0,
      unit: unit ?? Units.defaultUnit,
      cost: null,
    );
    recipe.ingredients.add(ingredient);
    notifyListeners();
    _persist();
    return AddIngredientResult.success;
  }

  /// Adds a new ingredient to the recipe pre-filled from a [PresetIngredient]
  /// (name/unit/quantity/cost), so the user doesn't have to retype common
  /// ingredients recipe after recipe.
  AddIngredientResult addIngredientFromPreset(
      String recipeId, PresetIngredient preset) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return AddIngredientResult.recipeFull;
    if (recipe.isFull) return AddIngredientResult.recipeFull;

    final refNumber = recipe.consumeNextRefNumber();
    final ingredient = Ingredient(
      id: 'ing_${_nextIngredientSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      refNumber: refNumber,
      name: preset.name,
      quantity: preset.quantity,
      unit: preset.unit,
      cost: preset.cost,
    );
    recipe.ingredients.add(ingredient);
    notifyListeners();
    _persist();
    return AddIngredientResult.success;
  }

  void deleteIngredient(String recipeId, String ingredientId) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.ingredients.removeWhere((i) => i.id == ingredientId);
    // If the deleted ingredient was the manually-picked base, clear it —
    // effectiveCalculateForRefNumber will fall back automatically.
    if (recipe.calculateForRefNumber != null &&
        !recipe.ingredients
            .any((i) => i.refNumber == recipe.calculateForRefNumber)) {
      recipe.calculateForRefNumber = null;
    }
    notifyListeners();
    _persist();
  }

  /// Reinserts a previously-deleted ingredient at [index] (clamped) —
  /// backs the "Undo" action on the ingredient delete snackbar.
  void restoreIngredient(String recipeId, Ingredient ingredient, int index) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    final clamped = index.clamp(0, recipe.ingredients.length);
    recipe.ingredients.insert(clamped, ingredient);
    notifyListeners();
    _persist();
  }

  void updateIngredientName(String recipeId, String ingredientId, String name) {
    _findIngredient(recipeId, ingredientId)?.name = name;
    notifyListeners();
    _persist();
  }

  void updateIngredientQuantity(
      String recipeId, String ingredientId, double quantity) {
    _findIngredient(recipeId, ingredientId)?.quantity = quantity;
    notifyListeners();
    _persist();
  }

  void updateIngredientUnit(String recipeId, String ingredientId, String unit) {
    _findIngredient(recipeId, ingredientId)?.unit = unit;
    notifyListeners();
    _persist();
  }

  void updateIngredientCost(
      String recipeId, String ingredientId, double? cost) {
    _findIngredient(recipeId, ingredientId)?.cost = cost;
    notifyListeners();
    _persist();
  }

  /// Updates the domain-specific extra field (e.g. CAS Number, INCI Name).
  void updateIngredientExtraField(
      String recipeId, String ingredientId, String value) {
    _findIngredient(recipeId, ingredientId)?.extraField = value;
    notifyListeners();
    _persist();
  }

  /// Converts an ingredient's quantity to [newUnit], keeping the physical
  /// amount constant (e.g. 1000 g -> 1 kg) rather than just relabeling it.
  /// [convertedQuantity] is the already-converted value — computed by the
  /// caller via `UnitConversion.convert` so this provider stays unit-math
  /// agnostic.
  void convertIngredientUnit(String recipeId, String ingredientId,
      String newUnit, double convertedQuantity) {
    final ingredient = _findIngredient(recipeId, ingredientId);
    if (ingredient == null) return;
    ingredient.quantity = convertedQuantity;
    ingredient.unit = newUnit;
    notifyListeners();
    _persist();
  }

  /// Toggling a checkbox can change which ingredient is the *first*
  /// checked one, which affects the "Calculate for" default. We simply
  /// notify — the default is recomputed live via
  /// [Recipe.effectiveCalculateForRefNumber].
  void updateIngredientIncluded(
      String recipeId, String ingredientId, bool included) {
    _findIngredient(recipeId, ingredientId)?.includeInCalculation = included;
    notifyListeners();
    _persist();
  }

  /// Checks or unchecks every ingredient's calculation checkbox at once —
  /// backs the "Select all" control on the recipe screen.
  void setAllIncludeInCalculation(String recipeId, bool included) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    for (final ingredient in recipe.ingredients) {
      ingredient.includeInCalculation = included;
    }
    notifyListeners();
    _persist();
  }

  Ingredient? _findIngredient(String recipeId, String ingredientId) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return null;
    for (final i in recipe.ingredients) {
      if (i.id == ingredientId) return i;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Calculate for / Calculate
  // ---------------------------------------------------------------------

  /// Records the user's manual pick in the "Calculate for" dropdown.
  /// Pass null to clear it and fall back to the first-checked default.
  void setCalculateForRefNumber(String recipeId, int? refNumber) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    recipe.calculateForRefNumber = refNumber;
    notifyListeners();
    _persist();
  }

  /// Scales every checked ingredient proportionally, based on the ratio
  /// between [targetQuantity] and the current quantity of the effective
  /// "Calculate for" ingredient (the user's manual pick, or — if none —
  /// the first checked ingredient). Unchecked ingredients are left as-is
  /// (their newQuantity/newCost mirror the original values).
  CalculateResult calculate(String recipeId, double targetQuantity) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return CalculateResult.noBaseSelected;

    final refNumber = recipe.effectiveCalculateForRefNumber;
    if (refNumber == null) return CalculateResult.noBaseSelected;

    if (targetQuantity.isNaN || targetQuantity < 0) {
      return CalculateResult.invalidTargetQuantity;
    }

    Ingredient? base;
    for (final i in recipe.ingredients) {
      if (i.refNumber == refNumber) {
        base = i;
        break;
      }
    }
    if (base == null) return CalculateResult.noBaseSelected;
    if (base.quantity == 0) return CalculateResult.baseQuantityIsZero;

    final ratio = targetQuantity / base.quantity;
    _applyRatio(recipe, ratio);

    notifyListeners();
    _persist();
    return CalculateResult.success;
  }

  /// Alternative to [calculate]: instead of scaling relative to one
  /// reference ingredient, scales every checked ingredient so their
  /// quantities sum to [targetTotal] — e.g. "make a 500 g batch total"
  /// rather than "make it so ingredient #2 is 100 g". Common for chemical
  /// or cosmetic formulations expressed as a percentage of total batch.
  ///
  /// [targetTotal] is interpreted in [targetUnit] — or, if null, the first
  /// checked ingredient's unit (see [Recipe.batchTotalUnit]). Every other
  /// checked ingredient's quantity is converted into that unit before
  /// summing, so e.g. 100 g + 0.1 kg correctly reads as 200 g rather than
  /// 100.1. If any checked ingredient's unit can't convert to it (mixing
  /// mass with a count unit like "piece", for instance), the sum wouldn't
  /// be meaningful, so this returns [CalculateResult.incompatibleUnits]
  /// instead of calculating.
  CalculateResult calculateByTotal(String recipeId, double targetTotal,
      {String? targetUnit}) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return CalculateResult.noBaseSelected;

    if (targetTotal.isNaN || targetTotal < 0) {
      return CalculateResult.invalidTargetQuantity;
    }

    final checked =
        recipe.ingredients.where((i) => i.includeInCalculation).toList();
    if (checked.isEmpty) return CalculateResult.noBaseSelected;

    final referenceUnit = targetUnit ?? checked.first.unit;
    var currentTotal = 0.0;
    for (final ingredient in checked) {
      final converted =
          UnitConversion.convert(ingredient.quantity, ingredient.unit, referenceUnit);
      if (converted == null) return CalculateResult.incompatibleUnits;
      currentTotal += converted;
    }
    if (currentTotal == 0) return CalculateResult.baseQuantityIsZero;

    final ratio = targetTotal / currentTotal;
    _applyRatio(recipe, ratio);

    notifyListeners();
    _persist();
    return CalculateResult.success;
  }

  /// Scales every checked ingredient's quantity/cost by [ratio]; unchecked
  /// ingredients keep their current values mirrored into new*.
  void _applyRatio(Recipe recipe, double ratio) {
    for (final ingredient in recipe.ingredients) {
      final cost = ingredient.cost;
      if (ingredient.includeInCalculation) {
        ingredient.newQuantity = ingredient.quantity * ratio;
        // No cost entered → no "new est. cost" figure to calculate/show.
        ingredient.newCost = cost != null ? cost * ratio : null;
      } else {
        ingredient.newQuantity = ingredient.quantity;
        ingredient.newCost = cost;
      }
    }
  }

  /// Clears the results of the most recent calculation (each ingredient's
  /// newQuantity/newCost) without touching quantity, cost, or checked
  /// state — backs the "Clear results" action on the Calculated summary.
  void clearCalculation(String recipeId) {
    final recipe = getRecipe(recipeId);
    if (recipe == null) return;
    for (final ingredient in recipe.ingredients) {
      ingredient.newQuantity = null;
      ingredient.newCost = null;
    }
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // Backup / restore
  // ---------------------------------------------------------------------

  Map<String, dynamic> exportAll() => {
        'recipes': _recipes.map((r) => r.toJson()).toList(),
        'nextRecipeSeq': _nextRecipeSeq,
        'nextIngredientSeq': _nextIngredientSeq,
      };

  Future<void> importAll(Map<String, dynamic> data) async {
    final decoded = (data['recipes'] as List<dynamic>? ?? [])
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
    _recipes
      ..clear()
      ..addAll(decoded);
    _nextRecipeSeq = data['nextRecipeSeq'] as int? ?? _nextRecipeSeq;
    _nextIngredientSeq =
        data['nextIngredientSeq'] as int? ?? _nextIngredientSeq;
    notifyListeners();
    await _persist();
  }
}
