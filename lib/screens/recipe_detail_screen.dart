import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/domain_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/domains.dart';
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
  late final TextEditingController _notesController;
  late final TabController _tabController;
  int _tabIndex = 0;
  _CalculationMode _calculationMode = _CalculationMode.byIngredient;

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
          content: Text('You\'ve reached the maximum of 30 ingredients.'),
        ),
      );
    }
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

  void _deleteIngredientWithUndo(
      BuildContext context, Recipe recipe, int index) {
    final provider = context.read<RecipeProvider>();
    final ingredient = recipe.ingredients[index];
    provider.deleteIngredient(recipe.id, ingredient.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${ingredient.displayName}"'),
        action: SnackBarAction(
          label: 'Undo',
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
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Blank ingredient'),
              subtitle: const Text('Type in the details yourself'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _addBlankIngredient(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('From preset'),
              subtitle: const Text('Pick from your saved ingredient groups'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showPresetPicker(context);
              },
            ),
            const SizedBox(height: 8),
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

  void _handleCalculate(BuildContext context, Recipe recipe) {
    final provider = context.read<RecipeProvider>();
    final targetText = _newQuantityController.text.trim();
    final target = double.tryParse(targetText);

    if (_calculationMode == _CalculationMode.byIngredient &&
        recipe.effectiveCalculateForRefNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Select (or check) an ingredient for "Calculate for" first.')),
      );
      return;
    }
    if (_calculationMode == _CalculationMode.byTotal &&
        !recipe.ingredients.any((i) => i.includeInCalculation)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Check at least one ingredient to include in the batch total.')),
      );
      return;
    }

    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid new quantity.')),
      );
      return;
    }

    final result = _calculationMode == _CalculationMode.byTotal
        ? provider.calculateByTotal(widget.recipeId, target)
        : provider.calculate(widget.recipeId, target);

    switch (result) {
      case CalculateResult.success:
        break;
      case CalculateResult.noBaseSelected:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_calculationMode == _CalculationMode.byTotal
                  ? 'Check at least one ingredient to include in the batch total.'
                  : 'Select (or check) an ingredient for "Calculate for" first.')),
        );
        break;
      case CalculateResult.invalidTargetQuantity:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid new quantity.')),
        );
        break;
      case CalculateResult.baseQuantityIsZero:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_calculationMode == _CalculationMode.byTotal
                  ? 'The checked ingredients currently total 0, so a ratio can\'t be calculated.'
                  : 'The selected ingredient\'s current quantity is 0, so a ratio can\'t be calculated.')),
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
            SnackBar(content: Text('Duplicated as "${copy.name}"')),
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
        const SnackBar(content: Text('Recipe saved.')),
      );
    }
  }

  Future<void> _showRenameDialog(BuildContext context, Recipe recipe) async {
    final controller = TextEditingController(text: recipe.name);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Recipe'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Recipe name'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Please enter a recipe name'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('Save'),
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
          title: const Text('Recipe Domain'),
          content: SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              initialValue: selectedDomainId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Domain'),
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(selectedDomainId),
              child: const Text('Save'),
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
        title: const Text('Batch Yield'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How much does this recipe currently make? Used to show a cost-per-unit summary.',
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
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(labelText: 'Yield'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      hintText: 'e.g. cookies, mL, bottles',
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
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(<String, String>{
              'quantity': quantityController.text.trim(),
              'unit': unitController.text.trim(),
            }),
            child: const Text('Save'),
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
        title: const Text('Export Recipe'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: SelectableText(text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard.')),
                );
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy to Clipboard'),
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
                Tab(icon: Icon(Icons.list_alt_outlined), text: 'Ingredients'),
                Tab(icon: Icon(Icons.notes_outlined), text: 'Notes'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Save recipe',
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
                      title: Text('Rename'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _RecipeMenuAction.domain,
                    child: ListTile(
                      leading: DomainIconBadge(domain: domain, size: 28),
                      title: Text('Domain: ${domain.name}'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _RecipeMenuAction.yieldInfo,
                    child: ListTile(
                      leading: const Icon(Icons.inventory_outlined),
                      title: Text(recipe.yieldQuantity == null
                          ? 'Set batch yield'
                          : 'Edit batch yield'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _RecipeMenuAction.duplicate,
                    child: ListTile(
                      leading: Icon(Icons.copy_outlined),
                      title: Text('Duplicate recipe'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _RecipeMenuAction.export,
                    child: ListTile(
                      leading: Icon(Icons.ios_share_outlined),
                      title: Text('Export / Share as text'),
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
                  onPressed: recipe.isFull
                      ? null
                      : () => _showAddIngredientOptions(context),
                  icon: const Icon(Icons.add),
                  label: Text(recipe.isFull
                      ? 'Max 30 reached'
                      : 'Add Ingredient (${recipe.ingredients.length}/${Recipe.maxIngredients})'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildIngredientsTab(BuildContext context, Recipe recipe,
      DomainDef domain, RecipeProvider provider) {
    return Column(
      children: [
        if (recipe.yieldQuantity != null)
          _YieldBanner(
            recipe: recipe,
            onTap: () => _showYieldDialog(context, recipe),
          ),
        _CalculateForBar(
          recipe: recipe,
          newQuantityController: _newQuantityController,
          mode: _calculationMode,
          onModeChanged: (mode) => setState(() => _calculationMode = mode),
          onCalculate: () => _handleCalculate(context, recipe),
        ),
        const Divider(height: 1),
        if (recipe.ingredients.isNotEmpty)
          _SelectAllForCalculationBar(recipe: recipe),
        Expanded(
          child: recipe.ingredients.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.egg_alt_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No ingredients yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the + button to add an ingredient.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: recipe.ingredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = recipe.ingredients[index];
                    return IngredientCard(
                      key: ValueKey(ingredient.id),
                      recipeId: recipe.id,
                      ingredient: ingredient,
                      costVisible: domain.costVisible,
                      extraFieldLabel: domain.extraFieldLabel,
                      referenceQuantity: _referenceQuantity(recipe),
                      onDelete: () =>
                          _deleteIngredientWithUndo(context, recipe, index),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Reference/documentation tab: photos of the finished result, plus a
/// full-page editor for notes/instructions — prep steps, mixing or
/// formulation procedure, serving suggestions, source, etc.
class _NotesTab extends StatelessWidget {
  final Recipe recipe;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NotesTab({
    required this.recipe,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PhotoSection(recipe: recipe),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Prep steps, mixing/formulation instructions, serving suggestions, source, etc.',
                alignLabelWithHint: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
    final text = StringBuffer('Yield: ${_formatNumber(qty)}');
    if (unit.isNotEmpty) text.write(' $unit');
    if (costPerUnit != null) {
      text.write(
          ' · $currencySymbol${costPerUnit.toStringAsFixed(2)}${unit.isNotEmpty ? '/$unit' : ' each'}');
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
class _CalculateForBar extends StatelessWidget {
  final Recipe recipe;
  final TextEditingController newQuantityController;
  final _CalculationMode mode;
  final ValueChanged<_CalculationMode> onModeChanged;
  final VoidCallback onCalculate;

  const _CalculateForBar({
    required this.recipe,
    required this.newQuantityController,
    required this.mode,
    required this.onModeChanged,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RecipeProvider>();
    final theme = Theme.of(context);
    final hasIngredients = recipe.ingredients.isNotEmpty;
    final effectiveRef = recipe.effectiveCalculateForRefNumber;
    final byTotal = mode == _CalculationMode.byTotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calculate',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SegmentedButton<_CalculationMode>(
            segments: const [
              ButtonSegment(
                value: _CalculationMode.byIngredient,
                label: Text('By ingredient'),
                icon: Icon(Icons.flag_outlined),
              ),
              ButtonSegment(
                value: _CalculationMode.byTotal,
                label: Text('By batch total'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
            ],
            selected: {mode},
            onSelectionChanged: hasIngredients
                ? (selection) => onModeChanged(selection.first)
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
                    hint: const Text('Select ingredient'),
                    decoration:
                        const InputDecoration(labelText: 'Calculate for'),
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
                        ? (value) =>
                            provider.setCalculateForRefNumber(recipe.id, value)
                        : null,
                  ),
                ),
              if (!byTotal) const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: newQuantityController,
                  enabled: hasIngredients,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                      labelText: byTotal ? 'Target batch total' : 'New quantity'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasIngredients ? onCalculate : null,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Calculate'),
            ),
          ),
          if (hasIngredients) ...[
            const SizedBox(height: 6),
            Text(
              byTotal
                  ? 'Only checked ingredients below are scaled, so their quantities sum to the target batch total.'
                  : 'Only checked ingredients below are scaled. "Calculate for" defaults to the first checked ingredient until you pick one manually.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
              'Select all for calculation',
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
