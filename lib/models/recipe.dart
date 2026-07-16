import '../utils/domains.dart';
import 'ingredient.dart';

/// Fallback timestamp for recipes saved before [Recipe.createdAt] existed —
/// consistently "oldest" rather than `DateTime.now()` (which would make
/// sort order shuffle on every load).
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

/// Represents a recipe containing a list of ingredients (max 30) and up to
/// [maxPhotos] photos.
class Recipe {
  static const int maxIngredients = 30;
  static const int maxPhotos = 3;

  final String id;
  String name;
  String notes;

  /// Which domain (category) this recipe belongs to — e.g. Food, Chemical.
  /// See [Domains]. Defaults to [Domains.defaultId] for recipes saved
  /// before this field existed.
  String domainId;
  final List<Ingredient> ingredients;

  /// Local file paths (mobile/desktop) or blob/network URLs (web) for
  /// photos attached to this recipe. Capped at [maxPhotos].
  final List<String> photoPaths;

  /// The ref number of the ingredient explicitly picked by the user in the
  /// "Calculate for" dropdown. Null means "no manual selection yet" — in
  /// that case the UI falls back to the first checked ingredient.
  int? calculateForRefNumber;

  /// When this recipe was created — powers "Newest"/"Oldest" dashboard
  /// sorting.
  final DateTime createdAt;

  /// When this recipe was last opened in the detail screen — powers
  /// "Recently opened" dashboard sorting. Null until first opened.
  DateTime? lastOpenedAt;

  /// Optional batch size this recipe's current quantities produce — e.g.
  /// 24 "cookies" or 500 "mL". Powers the yield/cost-per-unit summary.
  double? yieldQuantity;
  String yieldUnit;

  /// Whether the user has pinned this recipe as a favorite — powers the
  /// Dashboard's Favorites carousel.
  bool isFavorite;

  /// Monotonically increasing counter used to assign unique, stable
  /// ref numbers to ingredients — never reused even after deletion.
  int _nextRefNumber;

  Recipe({
    required this.id,
    required this.name,
    this.notes = '',
    String? domainId,
    List<Ingredient>? ingredients,
    List<String>? photoPaths,
    int nextRefNumber = 1,
    this.calculateForRefNumber,
    DateTime? createdAt,
    this.lastOpenedAt,
    this.yieldQuantity,
    this.yieldUnit = '',
    this.isFavorite = false,
  })  : domainId = domainId ?? Domains.defaultId,
        ingredients = ingredients ?? [],
        photoPaths = photoPaths ?? [],
        createdAt = createdAt ?? DateTime.now(),
        _nextRefNumber = nextRefNumber;

  int get nextRefNumber => _nextRefNumber;

  int consumeNextRefNumber() => _nextRefNumber++;

  bool get isFull => ingredients.length >= maxIngredients;

  bool get hasMaxPhotos => photoPaths.length >= maxPhotos;

  /// The ingredient the "Calculate for" dropdown should resolve to right
  /// now: the user's manual pick if it's still valid, otherwise the first
  /// checked ingredient in list order, otherwise null.
  int? get effectiveCalculateForRefNumber {
    final manual = calculateForRefNumber;
    if (manual != null && ingredients.any((i) => i.refNumber == manual)) {
      return manual;
    }
    for (final ingredient in ingredients) {
      if (ingredient.includeInCalculation) return ingredient.refNumber;
    }
    return null;
  }

  /// The unit "Calculate" > "By batch total" treats its target total as
  /// being expressed in by default — the first checked ingredient's unit.
  /// Null if no ingredient is checked. The user can override this via the
  /// "By batch total" unit picker, which only offers [checkedIngredientUnits].
  String? get batchTotalUnit {
    for (final ingredient in ingredients) {
      if (ingredient.includeInCalculation) return ingredient.unit;
    }
    return null;
  }

  /// Distinct units used by currently-checked ingredients, in the order
  /// they first appear — populates the "By batch total" unit picker so it
  /// only ever offers units actually in play, not the full unit catalog.
  Set<String> get checkedIngredientUnits => {
        for (final ingredient in ingredients)
          if (ingredient.includeInCalculation) ingredient.unit,
      };

  /// Sum of every ingredient's most current cost (its post-calculate
  /// `newCost` if one exists, otherwise its entered `cost`). Null if no
  /// ingredient has a cost entered at all.
  double? get totalCost {
    double sum = 0;
    var anyCost = false;
    for (final ingredient in ingredients) {
      final cost = ingredient.newCost ?? ingredient.cost;
      if (cost != null) {
        sum += cost;
        anyCost = true;
      }
    }
    return anyCost ? sum : null;
  }

  /// Cost per yield unit (e.g. cost per cookie), or null if yield or total
  /// cost isn't available.
  double? get costPerYieldUnit {
    final yieldQty = yieldQuantity;
    final cost = totalCost;
    if (yieldQty == null || yieldQty == 0 || cost == null) return null;
    return cost / yieldQty;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
        'domainId': domainId,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'photoPaths': photoPaths,
        'calculateForRefNumber': calculateForRefNumber,
        'nextRefNumber': _nextRefNumber,
        'createdAt': createdAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
        'yieldQuantity': yieldQuantity,
        'yieldUnit': yieldUnit,
        'isFavorite': isFavorite,
      };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled recipe',
      notes: json['notes'] as String? ?? '',
      domainId: json['domainId'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      photoPaths: (json['photoPaths'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      nextRefNumber: json['nextRefNumber'] as int? ?? 1,
      calculateForRefNumber: json['calculateForRefNumber'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : _epoch,
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.tryParse(json['lastOpenedAt'] as String)
          : null,
      yieldQuantity: (json['yieldQuantity'] as num?)?.toDouble(),
      yieldUnit: json['yieldUnit'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
