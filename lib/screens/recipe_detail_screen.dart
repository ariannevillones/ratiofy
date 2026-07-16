import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../providers/domain_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/domains.dart';
import '../utils/ui_labels.dart';
import '../utils/unit_conversion.dart';
import '../widgets/action_option_tile.dart';
import '../widgets/domain_icon.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/photo_section.dart';
import '../widgets/preset_picker_sheet.dart';

enum _RecipeMenuAction { rename, domain, yieldInfo, duplicate, export }

/// Whether "Calculate" scales relative to one reference ingredient (the
/// original behavior) or scales every checked ingredient so their
/// quantities sum to a target batch total.
enum _CalculationMode { byIngredient, byTotal }

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _newQuantityController = TextEditingController();
  final GlobalKey<FormState> _calculateFormKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late final TabController _tabController;
  int _tabIndex = 0;
  _CalculationMode _calculationMode = _CalculationMode.byIngredient;

  /// Id of an ingredient that was just added via "Blank ingredient" — its
  /// [IngredientCard] autofocuses its name field on first build, which
  /// (being inside a scrollable list) also scrolls it into view. Cleared
  /// right after that first build consumes it.
  String? _pendingFocusIngredientId;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: records this as the most recently opened recipe for
    // the dashboard's "Recently opened" sort.
    final recipeProvider = context.read<RecipeProvider>();
    recipeProvider.touchRecipe(widget.recipeId);

    _notesController = TextEditingController(
        text: recipeProvider.getRecipe(widget.recipeId)?.notes ?? '');

    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.index != _tabIndex) {
          setState(() => _tabIndex = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _newQuantityController.dispose();
    _notesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _addBlankIngredient(BuildContext context) {
    final provider = context.read<RecipeProvider>();
    final recipe = provider.getRecipe(widget.recipeId);
    final domain = context
        .read<DomainProvider>()
        .resolve(recipe?.domainId ?? Domains.defaultId);
    final result =
        provider.addIngredient(widget.recipeId, unit: domain.defaultUnit);
    if (result == AddIngredientResult.recipeFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(RecipeDetailLabels.maxIngredientsReached),
        ),
      );
      return;
    }

    final newIngredient = provider.getRecipe(widget.recipeId)!.ingredients.last;
    setState(() => _pendingFocusIngredientId = newIngredient.id);
    // Consumed after the one frame that needs it — autofocus only matters
    // on that ingredient's first build anyway, so this just keeps the
    // flag from lingering.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _pendingFocusIngredientId = null);
    });
  }

  /// Current quantity of the recipe's effective "Calculate for" reference
  /// ingredient, if any — feeds each [IngredientCard]'s percentage badge.
  double? _referenceQuantity(Recipe recipe) {
    final refNumber = recipe.effectiveCalculateForRefNumber;
    if (refNumber == null) return null;
    for (final ingredient in recipe.ingredients) {
      if (ingredient.refNumber == refNumber) return ingredient.quantity;
    }
    return null;
  }

  /// Takes the [Ingredient] itself (rather than a list index) since the
  /// ingredients tab displays them sorted (checked first), which no
  /// longer matches [Recipe.ingredients]' underlying storage order — the
  /// real index for delete/restore is looked up here instead.
  void _deleteIngredientWithUndo(
      BuildContext context, Recipe recipe, Ingredient ingredient) {
    final provider = context.read<RecipeProvider>();
    final index = recipe.ingredients.indexOf(ingredient);
    provider.deleteIngredient(recipe.id, ingredient.id);
    final messenger = ScaffoldMessenger.of(context);
    // Without this, deleting several ingredients in a row (there's no
    // confirmation step, unlike recipe deletion) queues each banner to
    // play its full duration one after another — from the outside that
    // reads as "the banner never goes away" even though each one is
    // individually capped at 1 second.
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(CommonLabels.deleted(ingredient.displayName)),
        duration: const Duration(seconds: 1),
        // SnackBar.persist defaults to true whenever an action is set
        // (ours has "Undo"), which makes it ignore `duration` entirely
        // and stay until manually dismissed — this override is what
        // actually makes the 1-second auto-dismiss take effect.
        persist: false,
        action: SnackBarAction(
          label: RecipeDetailLabels.undo,
          onPressed: () =>
              provider.restoreIngredient(recipe.id, ingredient, index),
        ),
      ),
    );
  }

  Future<void> _showAddIngredientOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  RecipeDetailLabels.addIngredientSheetTitle,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: ActionOptionTile(
                icon: Icons.add_circle_outline,
                title: RecipeDetailLabels.addOptionsBlankTitle,
                subtitle: RecipeDetailLabels.addOptionsBlankSubtitle,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _addBlankIngredient(context);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: ActionOptionTile(
                icon: Icons.inventory_2_outlined,
                title: RecipeDetailLabels.addOptionsPresetTitle,
                subtitle: RecipeDetailLabels.addOptionsPresetSubtitle,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showPresetPicker(context);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showPresetPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PresetPickerSheet(recipeId: widget.recipeId),
    );
  }

  void _handleCalculate(
      BuildContext context, Recipe recipe, String? batchTotalUnit) {
    final provider = context.read<RecipeProvider>();

    // Validates the "Calculate for" dropdown (required in byIngredient
    // mode) and the quantity field (required, must be a valid number) —
    // invalid/missing fields highlight in red inline instead of a snackbar.
    if (!(_calculateFormKey.currentState?.validate() ?? true)) return;

    final target = double.tryParse(_newQuantityController.text.trim()) ?? 0;

    if (_calculationMode == _CalculationMode.byTotal &&
        !recipe.ingredients.any((i) => i.includeInCalculation)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(RecipeDetailLabels.checkAtLeastOneForBatchTotal)),
      );
      return;
    }

    final result = _calculationMode == _CalculationMode.byTotal
        ? provider.calculateByTotal(widget.recipeId, target,
            targetUnit: batchTotalUnit)
        : provider.calculate(widget.recipeId, target);

    switch (result) {
      case CalculateResult.success:
        break;
      case CalculateResult.noBaseSelected:
        // Shouldn't happen now that the checks above run first, but handle
        // it defensively in case the mode/data changed underneath us.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_calculationMode == _CalculationMode.byTotal
                  ? RecipeDetailLabels.checkAtLeastOneForBatchTotal
                  : RecipeDetailLabels.selectIngredientForCalculateFor)),
        );
        break;
      case CalculateResult.invalidTargetQuantity:
        // Shouldn't happen now that the form validator checks this first.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(RecipeDetailLabels.enterValidNewQuantity)),
        );
        break;
      case CalculateResult.baseQuantityIsZero:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_calculationMode == _CalculationMode.byTotal
                  ? RecipeDetailLabels.checkedTotalIsZero
                  : RecipeDetailLabels.selectedQuantityIsZero)),
        );
        break;
      case CalculateResult.incompatibleUnits:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(RecipeDetailLabels.incompatibleUnitsForBatchTotal)),
        );
        break;
    }
  }

  Future<void> _handleMenuAction(
      BuildContext context, _RecipeMenuAction action, Recipe recipe) async {
    final provider = context.read<RecipeProvider>();

    switch (action) {
      case _RecipeMenuAction.rename:
        await _showRenameDialog(context, recipe);
        break;
      case _RecipeMenuAction.domain:
        await _showDomainDialog(context, recipe);
        break;
      case _RecipeMenuAction.yieldInfo:
        await _showYieldDialog(context, recipe);
        break;
      case _RecipeMenuAction.duplicate:
        final copy = provider.duplicateRecipe(recipe.id);
        if (copy != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(RecipeDetailLabels.duplicatedAs(copy.name))),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipeId: copy.id),
            ),
          );
        }
        break;
      case _RecipeMenuAction.export:
        await _showExportDialog(context, recipe);
        break;
    }
  }

  Future<void> _handleSave(BuildContext context) async {
    await context.read<RecipeProvider>().saveNow();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(RecipeDetailLabels.recipeSaved)),
      );
    }
  }

  Future<void> _showRenameDialog(BuildContext context, Recipe recipe) async {
    final controller = TextEditingController(text: recipe.name);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(RecipeDetailLabels.renameDialogTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: RecipeDetailLabels.recipeNameLabel),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? RecipeDetailLabels.pleaseEnterRecipeName
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(CommonLabels.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text(CommonLabels.save),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && context.mounted) {
      context.read<RecipeProvider>().renameRecipe(recipe.id, newName);
    }
  }

  Future<void> _showDomainDialog(BuildContext context, Recipe recipe) async {
    final domainProvider = context.read<DomainProvider>();
    final allDomains = domainProvider.allDomains;
    String selectedDomainId = recipe.domainId;

    final newDomainId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(RecipeDetailLabels.domainDialogTitle),
          content: SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              initialValue: selectedDomainId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: CommonLabels.domain),
              items: [
                for (final domain in allDomains)
                  DropdownMenuItem(
                    value: domain.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DomainIconBadge(domain: domain, size: 24),
                        const SizedBox(width: 8),
                        Text(domain.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() => selectedDomainId = value);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(CommonLabels.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(selectedDomainId),
              child: const Text(CommonLabels.save),
            ),
          ],
        ),
      ),
    );

    if (newDomainId != null && context.mounted) {
      context.read<RecipeProvider>().setRecipeDomain(recipe.id, newDomainId);
    }
  }

  Future<void> _showYieldDialog(BuildContext context, Recipe recipe) async {
    final quantityController = TextEditingController(
        text: recipe.yieldQuantity != null
            ? _formatForEditing(recipe.yieldQuantity!)
            : '');
    final unitController = TextEditingController(text: recipe.yieldUnit);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(RecipeDetailLabels.yieldDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              RecipeDetailLabels.yieldDialogDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: quantityController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                        labelText: RecipeDetailLabels.yieldLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: RecipeDetailLabels.yieldUnitLabel,
                      hintText: RecipeDetailLabels.yieldUnitHint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (recipe.yieldQuantity != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(<String, String>{'quantity': '', 'unit': ''}),
              child: const Text(CommonLabels.clear),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(CommonLabels.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(<String, String>{
              'quantity': quantityController.text.trim(),
              'unit': unitController.text.trim(),
            }),
            child: const Text(CommonLabels.save),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      final quantity = double.tryParse(result['quantity'] ?? '');
      context.read<RecipeProvider>().setRecipeYield(
            recipe.id,
            quantity: quantity,
            unit: quantity != null ? result['unit'] : null,
          );
    }
  }

  String _formatForEditing(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Future<void> _showExportDialog(BuildContext context, Recipe recipe) async {
    final currencySymbol = context.read<SettingsProvider>().currencySymbol;
    final text = context
        .read<RecipeProvider>()
        .exportRecipeAsText(recipe.id, currencySymbol: currencySymbol);

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(RecipeDetailLabels.exportDialogTitle),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: SelectableText(text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(CommonLabels.close),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(CommonLabels.copiedToClipboard)),
                );
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text(RecipeDetailLabels.copyToClipboard),
          ),
          FilledButton.icon(
            onPressed: () {
              // Captured before the dialog closes and the RenderBox goes away.
              final box = context.findRenderObject() as RenderBox?;
              final origin = box != null
                  ? box.localToGlobal(Offset.zero) & box.size
                  : null;
              Navigator.of(dialogContext).pop();
              Share.share(text,
                  subject: recipe.name, sharePositionOrigin: origin);
            },
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text(RecipeDetailLabels.shareRecipe),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RecipeProvider, DomainProvider>(
      builder: (context, provider, domainProvider, _) {
        final recipe = provider.getRecipe(widget.recipeId);

        if (recipe == null) {
          // Recipe was deleted (e.g. from another screen) — pop back.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) Navigator.of(context).pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final domain = domainProvider.resolve(recipe.domainId);

        return Scaffold(
          appBar: AppBar(
            title: Text(recipe.name),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                    icon: Icon(Icons.list_alt_outlined),
                    text: RecipeDetailLabels.ingredientsTab),
                Tab(
                    icon: Icon(Icons.notes_outlined),
                    text: RecipeDetailLabels.notesTab),
              ],
            ),
            actions: [
              IconButton(
                tooltip: recipe.isFavorite
                    ? RecipeCardLabels.unfavoriteTooltip
                    : RecipeCardLabels.favoriteTooltip,
                icon: Icon(
                  recipe.isFavorite ? Icons.star : Icons.star_border,
                  color: recipe.isFavorite
                      ? Theme.of(context).colorScheme.tertiary
                      : null,
                ),
                onPressed: () => provider.toggleFavorite(recipe.id),
              ),
              IconButton(
                tooltip: RecipeDetailLabels.saveRecipeTooltip,
                icon: const Icon(Icons.save_outlined),
                onPressed: () => _handleSave(context),
              ),
              PopupMenuButton<_RecipeMenuAction>(
                onSelected: (action) =>
                    _handleMenuAction(context, action, recipe),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _RecipeMenuAction.rename,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text(RecipeDetailLabels.menuRename),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _RecipeMenuAction.domain,
                    child: ListTile(
                      leading: DomainIconBadge(domain: domain, size: 28),
                      title: Text(RecipeDetailLabels.menuDomain(domain.name)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _RecipeMenuAction.yieldInfo,
                    child: ListTile(
                      leading: const Icon(Icons.inventory_outlined),
                      title: Text(recipe.yieldQuantity == null
                          ? RecipeDetailLabels.menuSetYield
                          : RecipeDetailLabels.menuEditYield),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _RecipeMenuAction.duplicate,
                    child: ListTile(
                      leading: Icon(Icons.copy_outlined),
                      title: Text(RecipeDetailLabels.menuDuplicate),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _RecipeMenuAction.export,
                    child: ListTile(
                      leading: Icon(Icons.ios_share_outlined),
                      title: Text(RecipeDetailLabels.menuExport),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildIngredientsTab(context, recipe, domain, provider),
              _NotesTab(
                recipe: recipe,
                controller: _notesController,
                onChanged: (value) =>
                    provider.updateRecipeNotes(recipe.id, value),
              ),
            ],
          ),
          floatingActionButton: _tabIndex == 0
              ? FloatingActionButton.extended(
                  heroTag: 'recipe_detail_add_ingredient_fab',
                  onPressed: recipe.isFull
                      ? null
                      : () => _showAddIngredientOptions(context),
                  icon: const Icon(Icons.add),
                  label: Text(recipe.isFull
                      ? RecipeDetailLabels.maxIngredientsFabLabel
                      : RecipeDetailLabels.addIngredientFabLabel(
                          recipe.ingredients.length, Recipe.maxIngredients)),
                )
              : null,
        );
      },
    );
  }

  /// The whole tab is one scrollable list — the Calculate bar (and its
  /// calculated-summary text, which can grow tall) scrolls together with
  /// the ingredient cards below it, rather than being a fixed header with
  /// only the ingredient list scrolling independently underneath.
  Widget _buildIngredientsTab(BuildContext context, Recipe recipe,
      DomainDef domain, RecipeProvider provider) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        if (recipe.yieldQuantity != null)
          _YieldBanner(
            recipe: recipe,
            onTap: () => _showYieldDialog(context, recipe),
          ),
        _CalculateForBar(
          recipe: recipe,
          formKey: _calculateFormKey,
          newQuantityController: _newQuantityController,
          mode: _calculationMode,
          onModeChanged: (mode) => setState(() => _calculationMode = mode),
          onCalculate: (batchTotalUnit) =>
              _handleCalculate(context, recipe, batchTotalUnit),
        ),
        const Divider(height: 1),
        if (recipe.ingredients.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              RecipeDetailLabels.ingredientsHeader(recipe.ingredients.length),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          _SelectAllForCalculationBar(recipe: recipe),
        ],
        if (recipe.ingredients.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.egg_alt_outlined,
                    size: 56, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(
                  RecipeDetailLabels.emptyIngredientsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  RecipeDetailLabels.emptyIngredientsSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          )
        else
          // Checked ingredients first, unchecked at the bottom — each
          // group keeps its original relative order (partition-and-concat
          // rather than a plain sort, so it's stable). This is purely a
          // display order; Recipe.ingredients' own storage order (and ref
          // numbers) is untouched.
          for (final ingredient in [
            ...recipe.ingredients.where((i) => i.includeInCalculation),
            ...recipe.ingredients.where((i) => !i.includeInCalculation),
          ])
            IngredientCard(
              key: ValueKey(ingredient.id),
              recipeId: recipe.id,
              ingredient: ingredient,
              costVisible: domain.costVisible,
              extraFieldLabel: domain.extraFieldLabel,
              referenceQuantity: _referenceQuantity(recipe),
              autofocus: ingredient.id == _pendingFocusIngredientId,
              onDelete: () =>
                  _deleteIngredientWithUndo(context, recipe, ingredient),
            ),
      ],
    );
  }
}

/// Reference/documentation tab: photos of the finished result, plus a
/// full-page editor for notes/instructions — prep steps, mixing or
/// formulation procedure, serving suggestions, source, etc. Notes support
/// lightweight markdown (bold, italic, bullet/numbered lists, links),
/// toggled between an editable field and a rendered preview.
class _NotesTab extends StatefulWidget {
  final Recipe recipe;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NotesTab({
    required this.recipe,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  bool _previewing = false;

  /// Wraps the current selection in [prefix]/[suffix] (e.g. `**bold**`).
  /// With no selection, inserts an empty pair and places the cursor
  /// between them so the user can type straight into it.
  void _wrapSelection(String prefix, [String? suffix]) {
    suffix ??= prefix;
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selected = text.substring(start, end);

    final newText = text.replaceRange(start, end, '$prefix$selected$suffix');
    controller.value = TextEditingValue(
      text: newText,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + prefix.length)
          : TextSelection(
              baseOffset: start,
              extentOffset:
                  start + prefix.length + selected.length + suffix.length,
            ),
    );
    widget.onChanged(newText);
  }

  /// Prefixes every line touched by the current selection (or just the
  /// current line, if nothing's selected) — backs the bullet/numbered
  /// list buttons. [prefixFor] receives the 0-based line index within
  /// the affected block, so numbered lists can count up.
  void _prefixLines(String Function(int lineIndex) prefixFor) {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    var lineEnd = text.indexOf('\n', end);
    if (lineEnd == -1) lineEnd = text.length;

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');
    final newBlock = [
      for (var i = 0; i < lines.length; i++) '${prefixFor(i)}${lines[i]}',
    ].join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, newBlock);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineEnd + (newBlock.length - block.length),
      ),
    );
    widget.onChanged(newText);
  }

  /// Inserts a `[text](url)` link — wrapping the selection as the link
  /// text if there is one — and selects the "url" placeholder so the
  /// user can type/paste the address immediately.
  void _insertLink() {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final linkText = text.substring(start, end).ifEmpty('text');
    const placeholderUrl = 'url';

    final newText =
        text.replaceRange(start, end, '[$linkText]($placeholderUrl)');
    final urlStart = start + linkText.length + 3; // '[' + linkText + ']('
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + placeholderUrl.length,
      ),
    );
    widget.onChanged(newText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNotes = widget.controller.text.trim().isNotEmpty;

    // The whole tab scrolls as one unit — photos and notes together —
    // rather than the notes field being the only scrollable region within
    // a fixed-height remainder below the photos.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        children: [
          PhotoSection(recipe: widget.recipe),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text(
                  RecipeDetailLabels.notesHeader,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _previewing
                      ? RecipeDetailLabels.notesEditTooltip
                      : RecipeDetailLabels.notesPreviewTooltip,
                  icon: Icon(_previewing
                      ? Icons.edit_outlined
                      : Icons.visibility_outlined),
                  onPressed: hasNotes || _previewing
                      ? () => setState(() => _previewing = !_previewing)
                      : null,
                ),
              ],
            ),
          ),
          if (_previewing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: MarkdownBody(
                  data: widget.controller.text,
                  selectable: true,
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrlString(href,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _MarkdownToolbar(
                onBold: () => _wrapSelection('**'),
                onItalic: () => _wrapSelection('*'),
                onBulletList: () => _prefixLines((_) => '- '),
                onNumberedList: () => _prefixLines((i) => '${i + 1}. '),
                onLink: _insertLink,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: widget.controller,
                maxLines: null,
                minLines: 10,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: RecipeDetailLabels.notesHint,
                  alignLabelWithHint: true,
                ),
                onChanged: (value) {
                  setState(() {}); // keep the Preview button's enabled state in sync
                  widget.onChanged(value);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// Row of formatting shortcut buttons above the notes field — inserts
/// markdown syntax at the cursor rather than being a live WYSIWYG toolbar.
class _MarkdownToolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onBulletList;
  final VoidCallback onNumberedList;
  final VoidCallback onLink;

  const _MarkdownToolbar({
    required this.onBold,
    required this.onItalic,
    required this.onBulletList,
    required this.onNumberedList,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            tooltip: RecipeDetailLabels.toolbarBold,
            icon: const Icon(Icons.format_bold),
            onPressed: onBold,
          ),
          IconButton(
            tooltip: RecipeDetailLabels.toolbarItalic,
            icon: const Icon(Icons.format_italic),
            onPressed: onItalic,
          ),
          IconButton(
            tooltip: RecipeDetailLabels.toolbarBulletList,
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: onBulletList,
          ),
          IconButton(
            tooltip: RecipeDetailLabels.toolbarNumberedList,
            icon: const Icon(Icons.format_list_numbered),
            onPressed: onNumberedList,
          ),
          IconButton(
            tooltip: RecipeDetailLabels.toolbarLink,
            icon: const Icon(Icons.link),
            onPressed: onLink,
          ),
        ],
      ),
    );
  }
}

/// Tappable banner showing the recipe's batch yield and, when a cost is
/// available, cost-per-unit — e.g. "Yield: 24 cookies · $0.42/cookie".
class _YieldBanner extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _YieldBanner({required this.recipe, required this.onTap});

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final qty = recipe.yieldQuantity;
    if (qty == null) return const SizedBox.shrink();

    final unit = recipe.yieldUnit.trim();
    final costPerUnit = recipe.costPerYieldUnit;
    final text =
        StringBuffer('${RecipeDetailLabels.yieldPrefix}${_formatNumber(qty)}');
    if (unit.isNotEmpty) text.write(' $unit');
    if (costPerUnit != null) {
      text.write(
          ' · $currencySymbol${costPerUnit.toStringAsFixed(2)}${unit.isNotEmpty ? '/$unit' : RecipeDetailLabels.eachSuffix}');
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        child: Row(
          children: [
            Icon(Icons.inventory_outlined,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text.toString(), style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Calculate for" row: a toggle between scaling relative to one
/// reference ingredient or to a target batch total, a target-quantity
/// input, and the Calculate button. Defaults to the first checked
/// ingredient whenever the user hasn't manually picked something else.
///
/// Collapsed by default — only the header (plus the current mode, and the
/// most recent results once there are any) shows until tapped open, so
/// the ingredient list itself is the first thing visible on the tab
/// instead of a full page of scaling controls.
class _CalculateForBar extends StatefulWidget {
  final Recipe recipe;
  final GlobalKey<FormState> formKey;
  final TextEditingController newQuantityController;
  final _CalculationMode mode;
  final ValueChanged<_CalculationMode> onModeChanged;

  /// Called when the Calculate button is pressed. In "By batch total"
  /// mode this carries the unit the target total should be interpreted
  /// in (from the unit picker); null in "By ingredient" mode, where it
  /// doesn't apply.
  final ValueChanged<String?> onCalculate;

  const _CalculateForBar({
    required this.recipe,
    required this.formKey,
    required this.newQuantityController,
    required this.mode,
    required this.onModeChanged,
    required this.onCalculate,
  });

  @override
  State<_CalculateForBar> createState() => _CalculateForBarState();
}

class _CalculateForBarState extends State<_CalculateForBar> {
  bool _expanded = false;

  /// Manual override for the "By batch total" unit picker. Null means
  /// "use the default" (the first checked ingredient's unit).
  String? _selectedBatchUnit;

  static String _formatQty(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  /// Ingredients that have been through a calculation (i.e. have a
  /// `newQuantity`), grouped into "Scaled" (checked, actually scaled by
  /// the ratio) and "Unchanged" (unchecked, mirrored as-is) so it's clear
  /// at a glance which is which — e.g. "Garlic - 200g, $1 → 400g, $2". In
  /// "by ingredient" mode, the reference ingredient the ratio was based on
  /// is pulled to the top of "Scaled" and labeled. In "by batch total"
  /// mode, a running total (converted into [batchUnit]) is appended to
  /// "Scaled" so it's easy to confirm the checked ingredients do sum to
  /// the target.
  String _calculatedSummary(String currencySymbol, String? batchUnit) {
    final recipe = widget.recipe;
    final mode = widget.mode;
    final basisRef = mode == _CalculationMode.byIngredient
        ? recipe.effectiveCalculateForRefNumber
        : null;

    final scaledLines = <String>[];
    final unchangedLines = <String>[];
    String? basisLine;
    var batchTotal = 0.0;
    var batchTotalKnown = batchUnit != null;

    for (final ingredient in recipe.ingredients) {
      final newQuantity = ingredient.newQuantity;
      if (newQuantity == null) continue;

      final oldPart = '${_formatQty(ingredient.quantity)} ${ingredient.unit}'
          '${ingredient.cost != null ? ', $currencySymbol${ingredient.cost!.toStringAsFixed(2)}' : ''}';
      final newPart = '${_formatQty(newQuantity)} ${ingredient.unit}'
          '${ingredient.newCost != null ? ', $currencySymbol${ingredient.newCost!.toStringAsFixed(2)}' : ''}';
      final baseLine = '${ingredient.displayName} : $oldPart → $newPart';

      if (!ingredient.includeInCalculation) {
        unchangedLines.add(baseLine);
        continue;
      }

      final isBasis = basisRef != null && ingredient.refNumber == basisRef;
      final line = isBasis
          ? '$baseLine${RecipeDetailLabels.basisForScalingSuffix}'
          : baseLine;
      if (isBasis) {
        basisLine = line;
      } else {
        scaledLines.add(line);
      }

      if (batchTotalKnown) {
        final converted =
            UnitConversion.convert(newQuantity, ingredient.unit, batchUnit!);
        if (converted == null) {
          batchTotalKnown = false;
        } else {
          batchTotal += converted;
        }
      }
    }
    if (basisLine != null) scaledLines.insert(0, basisLine);

    final blocks = <String>[];
    if (scaledLines.isNotEmpty) {
      final block = StringBuffer(RecipeDetailLabels.scaledGroupHeader)
        ..write('\n')
        ..write(scaledLines.join('\n'));
      if (mode == _CalculationMode.byTotal && batchTotalKnown) {
        block.write('\n');
        block.write(RecipeDetailLabels.batchTotalLine(
            _formatQty(batchTotal), batchUnit!));
      }
      blocks.add(block.toString());
    }
    if (unchangedLines.isNotEmpty) {
      blocks.add('${RecipeDetailLabels.unchangedGroupHeader}\n'
          '${unchangedLines.join('\n')}');
    }
    return blocks.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final mode = widget.mode;
    final provider = context.read<RecipeProvider>();
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final theme = Theme.of(context);
    final hasIngredients = recipe.ingredients.isNotEmpty;
    final effectiveRef = recipe.effectiveCalculateForRefNumber;
    final byTotal = mode == _CalculationMode.byTotal;
    final checkedUnits = recipe.checkedIngredientUnits;
    final effectiveBatchUnit = checkedUnits.isEmpty
        ? null
        : (_selectedBatchUnit != null &&
                checkedUnits.contains(_selectedBatchUnit)
            ? _selectedBatchUnit
            : checkedUnits.first);
    final summary = _calculatedSummary(
        currencySymbol, byTotal ? effectiveBatchUnit : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    RecipeDetailLabels.calculateRatioHeader,
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (!_expanded)
                  Text(
                    byTotal
                        ? RecipeDetailLabels.byTotalLabel
                        : RecipeDetailLabels.byIngredientLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Form(
              key: widget.formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<_CalculationMode>(
                    segments: const [
                      ButtonSegment(
                        value: _CalculationMode.byIngredient,
                        label: Text(RecipeDetailLabels.byIngredientLabel),
                        icon: Icon(Icons.flag_outlined),
                      ),
                      ButtonSegment(
                        value: _CalculationMode.byTotal,
                        label: Text(RecipeDetailLabels.byTotalLabel),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: hasIngredients
                        ? (selection) => widget.onModeChanged(selection.first)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!byTotal)
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<int>(
                            initialValue: effectiveRef,
                            isExpanded: true,
                            hint: const Text(
                                RecipeDetailLabels.selectIngredientHint),
                            decoration: const InputDecoration(
                                labelText:
                                    RecipeDetailLabels.calculateForLabel),
                            items: [
                              for (final ingredient in recipe.ingredients)
                                DropdownMenuItem(
                                  value: ingredient.refNumber,
                                  child: Text(
                                    ingredient.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: hasIngredients
                                ? (value) => provider.setCalculateForRefNumber(
                                    recipe.id, value)
                                : null,
                            validator: (value) => value == null
                                ? RecipeDetailLabels.requiredValidation
                                : null,
                          ),
                        ),
                      if (byTotal)
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            initialValue: effectiveBatchUnit,
                            isExpanded: true,
                            hint:
                                const Text(RecipeDetailLabels.batchUnitHint),
                            decoration: const InputDecoration(
                                labelText: RecipeDetailLabels.batchUnitLabel),
                            items: [
                              for (final unit in checkedUnits)
                                DropdownMenuItem(
                                    value: unit, child: Text(unit)),
                            ],
                            onChanged: checkedUnits.isEmpty
                                ? null
                                : (value) => setState(
                                    () => _selectedBatchUnit = value),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: widget.newQuantityController,
                          enabled: hasIngredients,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: InputDecoration(
                              labelText: byTotal
                                  ? RecipeDetailLabels.targetBatchTotalLabel(
                                      effectiveBatchUnit)
                                  : RecipeDetailLabels.newQuantityLabel),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return RecipeDetailLabels.requiredValidation;
                            }
                            final parsed = double.tryParse(trimmed);
                            if (parsed == null) {
                              return RecipeDetailLabels.invalidNumberValidation;
                            }
                            if (parsed < 0) {
                              return RecipeDetailLabels
                                  .mustBeAtLeastZeroValidation;
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: hasIngredients
                          ? () => widget.onCalculate(
                              byTotal ? effectiveBatchUnit : null)
                          : null,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text(RecipeDetailLabels.calculateButton),
                    ),
                  ),
                  if (hasIngredients) ...[
                    const SizedBox(height: 6),
                    Text(
                      byTotal
                          ? RecipeDetailLabels.byTotalHelperText
                          : RecipeDetailLabels.byIngredientHelperText,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          RecipeDetailLabels.calculatedHeader,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: RecipeDetailLabels.copyToClipboardTooltip,
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: summary));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text(CommonLabels.copiedToClipboard)),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: RecipeDetailLabels.clearResultsTooltip,
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => provider.clearCalculation(recipe.id),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                    child: SelectableText(
                      summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A "Select all" checkbox that checks/unchecks every ingredient's
/// calculation checkbox at once — shows an indeterminate (dash) state
/// when only some ingredients are checked.
class _SelectAllForCalculationBar extends StatelessWidget {
  final Recipe recipe;

  const _SelectAllForCalculationBar({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = recipe.ingredients.length;
    final checkedCount =
        recipe.ingredients.where((i) => i.includeInCalculation).length;
    final allChecked = total > 0 && checkedCount == total;
    final someChecked = checkedCount > 0 && checkedCount < total;

    return InkWell(
      onTap: () => context
          .read<RecipeProvider>()
          .setAllIncludeInCalculation(recipe.id, !allChecked),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
        child: Row(
          children: [
            Checkbox(
              tristate: true,
              value: allChecked ? true : (someChecked ? null : false),
              onChanged: (_) => context
                  .read<RecipeProvider>()
                  .setAllIncludeInCalculation(recipe.id, !allChecked),
            ),
            Text(
              RecipeDetailLabels.selectAllForCalculation,
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              '$checkedCount/$total',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
