/// One ingredient line within a [RecipeTemplate].
class RecipeTemplateIngredient {
  final String name;
  final double quantity;
  final String unit;

  const RecipeTemplateIngredient(this.name, this.quantity, this.unit);
}

/// A full presaved recipe/formula — name, domain, and a ready-made
/// ingredient list — that can be dropped into the app as a real [Recipe]
/// in one tap, rather than building one from scratch or one ingredient at
/// a time from presets.
class RecipeTemplate {
  final String name;
  final String domainId;
  final List<RecipeTemplateIngredient> ingredients;

  const RecipeTemplate({
    required this.name,
    required this.domainId,
    required this.ingredients,
  });
}

/// Catalog of built-in presaved recipes — the 3 most common recipes or
/// formulas per domain, sourced from general "most popular" / "beginner
/// starter" guides for each field rather than guessed.
class RecipeTemplates {
  static const List<RecipeTemplate> all = [
    // --- Food ---
    RecipeTemplate(
      name: 'Pancakes',
      domainId: 'food',
      ingredients: [
        RecipeTemplateIngredient('Flour', 1.5, 'cup'),
        RecipeTemplateIngredient('Sugar', 2, 'tbsp'),
        RecipeTemplateIngredient('Baking powder', 2, 'tsp'),
        RecipeTemplateIngredient('Salt', 0.5, 'tsp'),
        RecipeTemplateIngredient('Milk', 1.25, 'cup'),
        RecipeTemplateIngredient('Eggs', 1, 'piece'),
        RecipeTemplateIngredient('Butter', 3, 'tbsp'),
      ],
    ),
    RecipeTemplate(
      name: 'Chocolate Chip Cookies',
      domainId: 'food',
      ingredients: [
        RecipeTemplateIngredient('Flour', 2.25, 'cup'),
        RecipeTemplateIngredient('Butter', 1, 'cup'),
        RecipeTemplateIngredient('Sugar', 0.75, 'cup'),
        RecipeTemplateIngredient('Eggs', 2, 'piece'),
        RecipeTemplateIngredient('Baking soda', 1, 'tsp'),
        RecipeTemplateIngredient('Salt', 1, 'tsp'),
        RecipeTemplateIngredient('Chocolate chips', 2, 'cup'),
        RecipeTemplateIngredient('Vanilla extract', 1, 'tsp'),
      ],
    ),
    RecipeTemplate(
      name: 'Fried Rice',
      domainId: 'food',
      ingredients: [
        RecipeTemplateIngredient('Cooked rice', 3, 'cup'),
        RecipeTemplateIngredient('Eggs', 2, 'piece'),
        RecipeTemplateIngredient('Soy sauce', 3, 'tbsp'),
        RecipeTemplateIngredient('Garlic', 3, 'piece'),
        RecipeTemplateIngredient('Onion', 1, 'piece'),
        RecipeTemplateIngredient('Cooking oil', 2, 'tbsp'),
        RecipeTemplateIngredient('Green onion', 2, 'piece'),
      ],
    ),

    // --- Chemical ---
    RecipeTemplate(
      name: 'All-Purpose Cleaner',
      domainId: 'chemical',
      ingredients: [
        RecipeTemplateIngredient('Water', 1, 'cup'),
        RecipeTemplateIngredient('White vinegar', 1, 'cup'),
        RecipeTemplateIngredient('Isopropyl alcohol', 2, 'tbsp'),
        RecipeTemplateIngredient('Castile soap', 1, 'tsp'),
      ],
    ),
    RecipeTemplate(
      name: 'Glass & Window Cleaner',
      domainId: 'chemical',
      ingredients: [
        RecipeTemplateIngredient('Water', 1, 'cup'),
        RecipeTemplateIngredient('Vinegar', 2, 'tbsp'),
        RecipeTemplateIngredient('Isopropyl alcohol', 2, 'tbsp'),
        RecipeTemplateIngredient('Cornstarch', 1.5, 'tsp'),
      ],
    ),
    RecipeTemplate(
      name: 'Borax-Free Slime',
      domainId: 'chemical',
      ingredients: [
        RecipeTemplateIngredient('School glue', 0.5, 'cup'),
        RecipeTemplateIngredient('Baking soda', 0.5, 'tsp'),
        RecipeTemplateIngredient('Contact lens solution', 1, 'tbsp'),
      ],
    ),

    // --- Cosmetics ---
    RecipeTemplate(
      name: 'Lip Balm',
      domainId: 'cosmetics',
      ingredients: [
        RecipeTemplateIngredient('Beeswax', 1, 'tbsp'),
        RecipeTemplateIngredient('Shea butter', 1, 'tbsp'),
        RecipeTemplateIngredient('Coconut oil', 1, 'tbsp'),
        RecipeTemplateIngredient('Essential oil', 1, 'ml'),
      ],
    ),
    RecipeTemplate(
      name: 'Whipped Body Butter',
      domainId: 'cosmetics',
      ingredients: [
        RecipeTemplateIngredient('Shea butter', 100, 'g'),
        RecipeTemplateIngredient('Coconut oil', 50, 'g'),
        RecipeTemplateIngredient('Beeswax', 20, 'g'),
        RecipeTemplateIngredient('Vitamin E oil', 5, 'g'),
      ],
    ),
    RecipeTemplate(
      name: 'Basic Lotion',
      domainId: 'cosmetics',
      ingredients: [
        RecipeTemplateIngredient('Water', 100, 'g'),
        RecipeTemplateIngredient('Jojoba oil', 20, 'g'),
        RecipeTemplateIngredient('Emulsifying wax', 10, 'g'),
        RecipeTemplateIngredient('Glycerin', 5, 'g'),
      ],
    ),
  ];

  static List<RecipeTemplate> forDomain(String domainId) =>
      all.where((t) => t.domainId == domainId).toList(growable: false);
}
