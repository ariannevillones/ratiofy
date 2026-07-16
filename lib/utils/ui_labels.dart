/// Centralized, human-editable copy for the app's UI — dialog titles,
/// field labels, hints, tooltips, button text, and message templates.
/// Organized by screen/widget (matching the file that uses it) so wording
/// can be reviewed or changed in one place without hunting through widget
/// code. Purely static/structural strings only — recipe names, ingredient
/// names, and other user-entered data are never routed through here.
library;

/// Action words and short confirmation-dialog copy repeated verbatim
/// across many screens.
class CommonLabels {
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String save = 'Save';
  static const String add = 'Add';
  static const String create = 'Create';
  static const String close = 'Close';
  static const String edit = 'Edit';
  static const String done = 'Done';
  static const String clear = 'Clear';
  static const String clearSearch = 'Clear search';
  static const String domain = 'Domain';
  static const String allDomains = 'All domains';
  static const String all = 'All';
  static const String ingredients = 'Ingredients';
  static const String settings = 'Settings';
  static const String copiedToClipboard = 'Copied to clipboard.';
  static const String cannotBeUndone = 'This can\'t be undone.';
  static const String pleaseEnterAName = 'Please enter a name';

  /// e.g. 'Deleted "Garlic"' — used for both recipes and ingredients.
  static String deleted(String name) => 'Deleted "$name"';

  /// e.g. 'No ingredients match "chicken"' — used by every searchable
  /// list/picker in the app, with [kind] naming what's being searched.
  static String noMatchFor(String kind, String query) =>
      'No $kind match "$query"';
}

class RecipesLabels {
  static const String appBarTitle = 'Recipes/Formulas';
  static const String sortOldest = 'Oldest first';
  static const String sortNewest = 'Newest first';
  static const String sortNameAsc = 'Name (A-Z)';
  static const String sortRecentlyOpened = 'Recently opened';

  static const String newRecipeDialogTitle = 'New Recipe/Formula';
  static const String recipeNameLabel = 'Recipe/Formula name';

  static const String addOptionsBlankTitle = 'Blank recipe/formula';
  static const String addOptionsBlankSubtitle = 'Type in the details yourself';
  static const String addOptionsTemplateTitle = 'From Presaved Recipes/Formulas';
  static const String addOptionsTemplateSubtitle =
      'Start from a common recipe or formula';

  static const String deleteRecipeTitle = 'Delete recipe/formula?';
  static String deleteRecipeContent(String name) =>
      'This will permanently delete "$name". ${CommonLabels.cannotBeUndone}';

  static const String searchHint = 'Search recipes…';
  static const String closeSearchTooltip = 'Close search';
  static const String searchTooltip = 'Search recipes';
  static const String sortTooltip = 'Sort recipes';

  static const String emptyTitleNoRecipes = 'No recipes/formulas yet';
  static const String emptyTitleNoDomainMatch =
      'No recipes/formulas in this domain';
  static String emptyTitleNoSearchMatch(String query) =>
      'No recipes/formulas match "$query"';
  static const String emptySubtitleFirstRun = 'Tap the + button below to get started.';
  static const String emptySubtitleHasOthers =
      'Tap the + button to add your first recipe.';

  static const String addRecipeFabLabel = 'Add Recipe/Formula';

  static const String howItWorksTitle = 'How it works';
  static const String howItWorksStep1Title = 'Add a recipe or formula';
  static const String howItWorksStep1Subtitle =
      'Start blank, or from a presaved template.';
  static const String howItWorksStep2Title = 'List your ingredients';
  static const String howItWorksStep2Subtitle =
      'Enter each one with its quantity and unit.';
  static const String howItWorksStep3Title = 'Calculate to scale it';
  static const String howItWorksStep3Subtitle =
      'Change one ingredient\'s new quantity and every '
      'other ingredient scales with it automatically.';

  static const String templatePickerTitle = 'Presaved Recipes/Formulas';
  static const String templateSearchHint = 'Search recipes/formulas…';
  static String templateNoMatch(String query) =>
      CommonLabels.noMatchFor('recipes/formulas', query);
}

class RecipeDetailLabels {
  static const String maxIngredientsReached =
      'You\'ve reached the maximum of 30 ingredients.';
  static const String undo = 'Undo';

  static const String addIngredientSheetTitle = 'Add Ingredient';
  static const String addOptionsBlankTitle = 'Blank ingredient';
  static const String addOptionsBlankSubtitle = 'Type in the details yourself';
  static const String addOptionsPresetTitle = 'From Presaved ingredients';
  static const String addOptionsPresetSubtitle =
      'Pick from your saved ingredient groups';

  static const String checkAtLeastOneForBatchTotal =
      'Check at least one ingredient to include in the batch total.';
  static const String selectIngredientForCalculateFor =
      'Select (or check) an ingredient for "Calculate for" first.';
  static const String enterValidNewQuantity = 'Enter a valid new quantity.';
  static const String checkedTotalIsZero =
      'The checked ingredients currently total 0, so a ratio can\'t be calculated.';
  static const String selectedQuantityIsZero =
      'The selected ingredient\'s current quantity is 0, so a ratio can\'t be calculated.';
  static const String incompatibleUnitsForBatchTotal =
      'Checked ingredients use units that can\'t be added together (e.g. mass and count) — use matching units for a batch total.';

  static String duplicatedAs(String name) => 'Duplicated as "$name"';
  static const String recipeSaved = 'Recipe saved.';

  static const String renameDialogTitle = 'Rename Recipe/Formula';
  static const String recipeNameLabel = 'Recipe name';
  static const String pleaseEnterRecipeName = 'Please enter a recipe name';

  static const String domainDialogTitle = 'Recipe/Formula Domain';

  static const String yieldDialogTitle = 'Batch Yield';
  static const String yieldDialogDescription =
      'How much does this recipe currently make? Used to show a cost-per-unit summary.';
  static const String yieldLabel = 'Yield';
  static const String yieldUnitLabel = 'Unit';
  static const String yieldUnitHint = 'e.g. cookies, mL, bottles';

  static const String exportDialogTitle = 'Export Recipe/Formula';
  static const String copyToClipboard = 'Copy to Clipboard';
  static const String shareRecipe = 'Share';

  static const String ingredientsTab = 'Ingredients';
  static const String notesTab = 'Notes';
  static const String saveRecipeTooltip = 'Save recipe';

  static const String menuRename = 'Rename';
  static String menuDomain(String domainName) => 'Domain: $domainName';
  static const String menuSetYield = 'Set batch yield';
  static const String menuEditYield = 'Edit batch yield';
  static const String menuDuplicate = 'Duplicate recipe/formula';
  static const String menuExport = 'Export / Share as text';

  static const String maxIngredientsFabLabel = 'Max 30 reached';
  static String addIngredientFabLabel(int count, int max) =>
      'Add Ingredient ($count/$max)';
  static String ingredientsHeader(int count) => 'Ingredients ($count)';

  static const String emptyIngredientsTitle = 'No ingredients yet';
  static const String emptyIngredientsSubtitle =
      'Tap the + button to add an ingredient.';

  static const String notesHeader = 'Notes';
  static const String notesEditTooltip = 'Edit';
  static const String notesPreviewTooltip = 'Preview';
  static const String notesHint =
      'Prep steps, mixing/formulation instructions, '
      'serving suggestions, source, etc.\n\nSupports '
      '**bold**, *italic*, bullet/numbered lists, and links.';
  static const String toolbarBold = 'Bold';
  static const String toolbarItalic = 'Italic';
  static const String toolbarBulletList = 'Bulleted list';
  static const String toolbarNumberedList = 'Numbered list';
  static const String toolbarLink = 'Link';

  static const String yieldPrefix = 'Yield: ';
  static const String eachSuffix = ' each';

  static const String calculateRatioHeader = 'Calculate ratio';
  static const String byIngredientLabel = 'By ingredient';
  static const String byTotalLabel = 'By batch total';
  static const String selectIngredientHint = 'Select ingredient';
  static const String calculateForLabel = 'Calculate for';
  static String targetBatchTotalLabel(String? unit) =>
      unit == null ? 'Target batch total' : 'Target batch total ($unit)';
  static const String newQuantityLabel = 'New quantity';
  static const String requiredValidation = 'Required';
  static const String invalidNumberValidation = 'Invalid number';
  static const String mustBeAtLeastZeroValidation = 'Must be ≥ 0';
  static const String calculateButton = 'Calculate';
  static const String byTotalHelperText =
      'Only checked ingredients below are scaled, so their quantities sum to the target batch total.';
  static const String byIngredientHelperText =
      'Only checked ingredients below are scaled. "Calculate for" defaults to the first checked ingredient until you pick one manually.';
  static const String calculatedHeader = 'Calculated';
  static const String copyToClipboardTooltip = 'Copy to clipboard';
  static const String clearResultsTooltip = 'Clear results';
  static const String basisForScalingSuffix = ' (basis for scaling)';
  static const String selectAllForCalculation = 'Select all for calculation';

  static const String batchUnitLabel = 'Unit';
  static const String batchUnitHint = 'Check ingredients first';
  static const String scaledGroupHeader = 'Scaled';
  static const String unchangedGroupHeader = 'Unchanged';
  static String batchTotalLine(String total, String unit) =>
      'Total: $total $unit';
}

class PresetsLabels {
  static const String appBarTitle = CommonLabels.ingredients;
  static const String searchHint = 'Search ingredients…';
  static const String closeSearchTooltip = 'Close search';
  static const String searchTooltip = 'Search ingredients';

  static String noIngredientsMatch(String query) =>
      CommonLabels.noMatchFor('ingredients', query);

  static const String newGroupFabLabel = 'New Group';
  static const String addIngredientFabLabel = 'Add Ingredient';

  static const String newGroupDialogTitle = 'New Preset Group';
  static const String groupLabelLabel = 'Group label';
  static const String groupLabelHint = 'e.g. Filipino Savory Staples';
  static const String pleaseEnterALabel = 'Please enter a label';
  static const String groupDomainOptionalLabel = 'Domain (optional)';

  static const String newIngredientDialogTitle = 'New Ingredient';
  static const String editIngredientDialogTitle = 'Edit Preset Ingredient';
  static const String ingredientNameLabel = 'Ingredient name';
  static const String ingredientNameHint = 'e.g. Garlic';
  static const String defaultQuantityLabel = 'Default quantity';
  static const String defaultCostOptionalLabel = 'Default cost (optional)';
  static const String ingredientGroupOptionalLabel = 'Group (optional)';
  static const String ungrouped = 'Ungrouped';

  static const String renameGroupDialogTitle = 'Rename Group';
  static const String groupDomainDialogTitle = 'Group Domain';

  static const String deleteGroupTitle = 'Delete group?';
  static String deleteGroupContent(String label, int count) =>
      '"$label" and its $count preset ingredient(s) will be removed.';

  static const String deleteSelectedTitle = 'Delete selected ingredients?';
  static String deleteSelectedContent(int count, String groupLabel) =>
      '$count ingredient(s) will be removed from "$groupLabel".';

  static const String selectIngredientsTooltip = 'Select ingredients';
  static const String renameGroupMenuItem = 'Rename group';
  static const String changeDomainMenuItem = 'Change domain';
  static const String deleteGroupMenuItem = 'Delete group';

  static const String selectAll = 'Select all';
  static const String editTooltip = 'Edit';
  static const String deleteTooltip = 'Delete';
  static String deleteSelectedButton(int count) => 'Delete Selected ($count)';
  static const String emptyGroupHint =
      'No ingredients yet — use the Add Ingredient button below.';

  static String ingredientCountSubtitle(int count, {required bool ungrouped}) {
    if (ungrouped) {
      return count == 1
          ? '1 ingredient without a group'
          : '$count ingredients without a group';
    }
    return count == 1 ? '1 ingredient' : '$count ingredients';
  }

  static const String matchingSuffix = ' matching';
}

class SettingsLabels {
  static const String appBarTitle = CommonLabels.settings;

  static const String newDomainDialogTitle = 'New Domain';
  static const String domainNameLabel = 'Domain name';
  static const String domainNameHint = 'e.g. Candles, Aquarium Mix';
  static const String iconLabel = 'Icon';
  static const String colorLabel = 'Color';
  static const String defaultUnitLabel = 'Default unit for new ingredients';
  static const String showCostFieldTitle = 'Show cost field';
  static const String showCostFieldSubtitle =
      'Turn off for domains where price isn\'t relevant';
  static const String extraFieldOptionalLabel = 'Extra field (optional)';
  static const String extraFieldHint = 'e.g. CAS Number, INCI Name, Batch code';

  static const String exportDialogTitle = 'Export Backup';
  static const String copyToClipboardButton = 'Copy to Clipboard';

  static const String importDialogTitle = 'Import Backup';
  static const String importHint = 'Paste a backup exported from this app';
  static const String importButton = 'Import';
  static const String invalidBackup = 'That doesn\'t look like a valid backup.';

  static const String replaceAllDataTitle = 'Replace all data?';
  static const String replaceAllDataContent =
      'Importing will replace every recipe, preset, and domain currently in the app. This can\'t be undone.';
  static const String replaceButton = 'Replace';
  static const String backupImported = 'Backup imported.';

  static const String deleteDomainTitle = 'Delete domain?';
  static String deleteDomainContent(String name) =>
      '"$name" will be removed. Recipes already using it will fall back to "Other".';

  static const String themeHeader = 'Theme';
  static const String themeDescription =
      'Choose how Ratiofy looks, or follow your device setting.';
  static const String themeSystem = 'System';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';

  static const String currencyHeader = 'Currency';
  static const String currencyDescription =
      'Used for all ingredient cost fields across every recipe.';
  static const String defaultCurrencyLabel = 'Default currency';

  static const String domainsHeader = 'Domains';
  static const String domainsDescription =
      'Categorize recipes by domain — Food, Chemical, Cosmetics, and Other are built in. Add your own for anything else.';
  static const String builtIn = 'Built-in';
  static const String deleteDomainTooltip = 'Delete domain';
  static const String addDomain = 'Add domain';

  static const String backupHeader = 'Backup & Restore';
  static const String backupDescription =
      'Everything is stored only on this device. Export a backup before reinstalling or switching devices.';
  static const String exportAllData = 'Export all data';
  static const String exportAllDataSubtitle = 'Copy a backup to your clipboard';
  static const String importBackup = 'Import backup';
  static const String importBackupSubtitle = 'Replaces all current data';

  static const String aboutHeader = 'About';
  static String versionLabel(String version) => 'v$version';
  static const String openSourceLicenses = 'Open-source licenses';
}

class OnboardingLabels {
  static const String skip = 'Skip';
  static const String next = 'Next';
  static const String getStarted = 'Get Started';

  static const String page1Title = 'Scale anything by ratio';
  static const String page1Body =
      'Ratiofy keeps every ingredient proportional when you change one '
      'quantity — pick a reference ingredient (or a target batch total) '
      'and everything else scales with it automatically.';

  static const String page2Title = 'Organize by domain';
  static const String page2Body =
      'Food, Chemical, Cosmetics, or your own custom domain — each with '
      'its own default unit, optional extra field, and ingredient presets.';

  static const String page3Title = 'Add, list, calculate';
  static const String page3Step1 = 'Add a recipe or formula';
  static const String page3Step2 = 'List your ingredients with quantities';
  static const String page3Step3 = 'Calculate to scale it — instantly';

  static const String page4Title = 'A couple extra tools';
  static const String page4QuickCalcTitle = 'Quick Ratio Calculator';
  static const String page4QuickCalcBody =
      'Solve a:b = c:d for a one-off ratio, no recipe needed.';
  static const String page4PresetsTitle = 'Presaved Ingredients';
  static const String page4PresetsBody =
      'Save common ingredient groups to reuse across recipes.';
}

class HomeShellLabels {
  static const String dashboardTab = 'Home';
  static const String recipesTab = 'Recipes/Formulas';
  static const String ingredientsTab = CommonLabels.ingredients;
  static const String settingsTab = CommonLabels.settings;
}

class DashboardLabels {
  static const String recipeStatSingular = 'Recipe/Formula';
  static const String recipeStatPlural = 'Recipes/Formulas';
  static const String ingredientStat = CommonLabels.ingredients;
  static const String costStat = 'Total Cost';

  static const String addRecipeCardTitle = 'Add Recipe/Formula';

  static const String quickCalculatorTitle = 'Quick Ratio Calculator';

  static const String continueLabel = 'Continue where you left off';

  static const String favoritesHeader = 'Favorites';

  static const String recentRecipesHeader = 'Recently Added';
  static const String noRecentRecipesYet =
      'No recipes yet — add one from the Recipes/Formulas tab.';
}

class QuickCalculatorLabels {
  static const String title = 'Quick Ratio Calculator';
  static const String description = 'Solve a:b = c:d — fill in any three '
      'values and pick which one to solve for.';
  static const String solveForLabel = 'Solve for';
  static const String calculateButton = 'Calculate';
  static const String clearButton = CommonLabels.clear;
  static const String resultLabel = 'Result';
  static const String requiredValidation = RecipeDetailLabels.requiredValidation;
  static const String invalidNumberValidation =
      RecipeDetailLabels.invalidNumberValidation;
  static const String divisionByZero =
      'The other two values in that ratio are 0, so it can\'t be solved.';
  static const String shareResult = 'Share result';
  static String shareText(
          String a, String b, String c, String d) =>
      '$a : $b = $c : $d';

  static const String howItWorksTitle = 'How it works';
  static const String howItWorksBody =
      'Pick which value (a, b, c, or d) you want to solve for, then fill '
      'in the other three. Ratiofy cross-multiplies to solve a:b = c:d '
      'instantly — handy for a single, one-off conversion.';

  static const String moreValuesTitle = 'Need to calculate more values?';
  static const String moreValuesBody =
      'This solves one ratio at a time. A Recipe/Formula scales a whole '
      'list of ingredients together, keeping every quantity proportional.';
  static const String createRecipeButton = 'Create Recipe/Formula';
}

class IngredientCardLabels {
  static const String nameLabel = 'Ingredient name';
  static const String nameHint = 'e.g. Onions, Garlic, Soy sauce';
  static const String deleteTooltip = 'Delete ingredient';
  static const String collapseTooltip = 'Collapse';
  static const String percentageTooltip = 'Share of the "Calculate for" reference';
  static const String quantityLabel = 'Quantity';
  static const String convertUnitTooltip = 'Convert to another unit';
  static const String costLabel = 'Cost (optional)';
  static const String costHint = 'e.g. 2.50';
  static const String newQuantityStat = 'New quantity';
  static const String newCostStat = 'New est. cost';

  static const String convertDialogTitle = 'Convert Unit';
  static const String convertToLabel = 'Convert to';
  static const String applyButton = 'Apply';
  static const String equalsSuffix = ' equals:';
}

class PhotoSectionLabels {
  static const String maxPhotosReached = 'You can add up to 3 photos per recipe.';
  static String cameraAccessError(Object error) =>
      'Couldn\'t access camera/gallery: $error';
  static const String takePhoto = 'Take Photo';
  static const String chooseFromGallery = 'Choose from Gallery';
  static const String closeTooltip = 'Close';
  static const String deletePhotoTooltip = 'Delete photo';
  static const String deletePhotoTitle = 'Delete photo?';
  static const String photosLabel = 'Photos';
  static String photoCount(int count, int max) => '($count/$max)';
}

class RecipeCardLabels {
  static String ingredientCount(int count) =>
      count == 1 ? '1 ingredient' : '$count ingredients';
  static const String deleteTooltip = 'Delete recipe';
  static const String favoriteTooltip = 'Add to favorites';
  static const String unfavoriteTooltip = 'Remove from favorites';
}

class UnitPickerLabels {
  static const String defaultFieldLabel = 'Unit';
  static const String pickerTitle = 'Select Unit';
  static const String searchHint = 'Search units…';
  static String noUnitsMatch(String query) =>
      CommonLabels.noMatchFor('units', query);
}

class PresetPickerLabels {
  static const String title = 'Add from Presaved Ingredients';
  static const String manage = 'Manage';
  static const String searchHint = 'Search ingredients…';
  static const String noPresetsConfigured = 'No presets configured yet.';
  static const String noPresetsHint =
      'Tap "Manage" above to create a group like "Filipino Savory Staples".';
  static String noIngredientsMatch(String query) =>
      CommonLabels.noMatchFor('ingredients', query);
  static const String selectIngredientsToAdd = 'Select ingredients to add';
  static String addSelected(int count) => 'Add Selected ($count)';

  static String addedCount(int count) =>
      'Added $count ingredient(s) — stopped at the 30-ingredient limit.';
  static String addedCountNoLimit(int count) => 'Added $count ingredient(s).';
  static const String recipeAlreadyFull =
      'This recipe already has the maximum of 30 ingredients.';
}
