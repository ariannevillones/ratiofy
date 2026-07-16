import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/ui_labels.dart';
import '../utils/unit_conversion.dart';
import 'unit_dropdown_field.dart';

class IngredientCard extends StatefulWidget {
  final String recipeId;
  final Ingredient ingredient;
  final VoidCallback onDelete;

  /// Whether this recipe's domain shows the Cost field. When false, the
  /// cost input is hidden and only quantity is scaled/shown.
  final bool costVisible;

  /// Label for the domain's optional extra field (e.g. "CAS Number"). Empty
  /// hides the field entirely.
  final String extraFieldLabel;

  /// The recipe's current "Calculate for" reference ingredient's quantity,
  /// used to show this ingredient's baker's-percentage-style share of it.
  /// Null hides the percentage badge.
  final double? referenceQuantity;

  /// Autofocuses the name field on this card's first build — used for a
  /// just-added blank ingredient so the user lands straight in it (also
  /// scrolls it into view, since it sits in a scrollable list).
  final bool autofocus;

  const IngredientCard({
    required Key key,
    required this.recipeId,
    required this.ingredient,
    required this.onDelete,
    this.costVisible = true,
    this.extraFieldLabel = '',
    this.referenceQuantity,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<IngredientCard> {
  /// Overrides the auto-collapse-when-unchecked behavior so an excluded
  /// ingredient can still be edited — tapping the collapsed row sets this,
  /// and it stays expanded until tapped closed again.
  bool _manuallyExpanded = false;

  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _costController;
  late final TextEditingController _extraFieldController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ingredient.name);
    _quantityController = TextEditingController(
        text: _formatForEditing(widget.ingredient.quantity));
    _costController = TextEditingController(
        text: widget.ingredient.cost != null
            ? _formatForEditing(widget.ingredient.cost!)
            : '');
    _extraFieldController =
        TextEditingController(text: widget.ingredient.extraField);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _extraFieldController.dispose();
    super.dispose();
  }

  String _formatForEditing(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  String _formatDisplay(double? value, {String prefix = ''}) {
    if (value == null) return '—';
    return '$prefix${value.toStringAsFixed(2)}';
  }

  Future<void> _showConvertDialog(BuildContext context) async {
    final ingredient = widget.ingredient;
    final options = UnitConversion.compatibleUnits(ingredient.unit);
    if (options.isEmpty) return;

    String targetUnit = options.first;
    final provider = context.read<RecipeProvider>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final converted = UnitConversion.convert(
              ingredient.quantity, ingredient.unit, targetUnit);
          return AlertDialog(
            title: const Text(IngredientCardLabels.convertDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${_formatForEditing(ingredient.quantity)} ${ingredient.unit}${IngredientCardLabels.equalsSuffix}'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: IngredientCardLabels.convertToLabel),
                  items: [
                    for (final unit in options)
                      DropdownMenuItem(value: unit, child: Text(unit)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => targetUnit = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  converted != null
                      ? '${converted.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')} $targetUnit'
                      : '—',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(CommonLabels.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(targetUnit),
                child: const Text(IngredientCardLabels.applyButton),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && context.mounted) {
      final converted =
          UnitConversion.convert(ingredient.quantity, ingredient.unit, result);
      if (converted != null) {
        provider.convertIngredientUnit(
            widget.recipeId, ingredient.id, result, converted);
        setState(() {
          _quantityController.text = _formatForEditing(converted);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RecipeProvider>();
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final ingredient = widget.ingredient;
    final theme = Theme.of(context);
    final hasCost = widget.costVisible && ingredient.cost != null;
    final refQty = widget.referenceQuantity;
    final percentage = (refQty != null && refQty != 0)
        ? (ingredient.quantity / refQty * 100)
        : null;
    final canConvertUnit =
        UnitConversion.compatibleUnits(ingredient.unit).isNotEmpty;
    // Collapsed to just a name row when excluded from calculation — an
    // "unchecked" ingredient is usually something set aside (packaging,
    // "to taste", etc.) and doesn't need its full form taking up space.
    // Manually re-expanding (to fix a typo, say) overrides this until
    // toggled closed again.
    final isCollapsed = !ingredient.includeInCalculation && !_manuallyExpanded;
    // A flat, receded background marks an excluded ingredient regardless
    // of whether it's collapsed or manually re-expanded for editing.
    // Note: Card's own unset-color default *is* surfaceContainerLow (see
    // Flutter's M3 CardTheme defaults), so that shade is indistinguishable
    // from a normal checked card — colorScheme.surface (the Scaffold's own
    // background) is what actually reads as visually different here.
    final cardColor = ingredient.includeInCalculation
        ? null
        : theme.colorScheme.surface;

    if (isCollapsed) {
      return Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(
            children: [
              Checkbox(
                value: ingredient.includeInCalculation,
                onChanged: (checked) => provider.updateIngredientIncluded(
                    widget.recipeId, ingredient.id, checked ?? false),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _manuallyExpanded = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      ingredient.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: IngredientCardLabels.deleteTooltip,
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: checkbox, % badge, collapse toggle, delete button
            Row(
              children: [
                Checkbox(
                  value: ingredient.includeInCalculation,
                  onChanged: (checked) {
                    provider.updateIngredientIncluded(
                        widget.recipeId, ingredient.id, checked ?? false);
                  },
                ),
                if (percentage != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: IngredientCardLabels.percentageTooltip,
                    child: Chip(
                      label: Text('${percentage.toStringAsFixed(1)}%'),
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: theme.colorScheme.tertiaryContainer,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                const Spacer(),
                if (!ingredient.includeInCalculation)
                  IconButton(
                    tooltip: IngredientCardLabels.collapseTooltip,
                    icon: const Icon(Icons.unfold_less),
                    onPressed: () =>
                        setState(() => _manuallyExpanded = false),
                  ),
                IconButton.outlined(
                  tooltip: IngredientCardLabels.deleteTooltip,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Name
            TextFormField(
              controller: _nameController,
              autofocus: widget.autofocus,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: IngredientCardLabels.nameLabel,
                hintText: IngredientCardLabels.nameHint,
              ),
              onChanged: (value) => provider.updateIngredientName(
                  widget.recipeId, ingredient.id, value),
            ),
            if (widget.extraFieldLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _extraFieldController,
                decoration: InputDecoration(labelText: widget.extraFieldLabel),
                onChanged: (value) => provider.updateIngredientExtraField(
                    widget.recipeId, ingredient.id, value),
              ),
            ],
            const SizedBox(height: 10),
            // Quantity + Unit
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                        labelText: IngredientCardLabels.quantityLabel),
                    onChanged: (value) {
                      final parsed = double.tryParse(value) ?? 0;
                      provider.updateIngredientQuantity(
                          widget.recipeId, ingredient.id, parsed);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: UnitDropdownField(
                    value: ingredient.unit,
                    onChanged: (value) {
                      provider.updateIngredientUnit(
                          widget.recipeId, ingredient.id, value);
                    },
                  ),
                ),
                if (canConvertUnit)
                  IconButton(
                    tooltip: IngredientCardLabels.convertUnitTooltip,
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () => _showConvertDialog(context),
                  ),
              ],
            ),
            if (widget.costVisible) ...[
              const SizedBox(height: 10),
              // Cost (optional)
              TextFormField(
                controller: _costController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: IngredientCardLabels.costLabel,
                  hintText: IngredientCardLabels.costHint,
                  prefixText: '$currencySymbol ',
                ),
                onChanged: (value) {
                  final trimmed = value.trim();
                  final parsed =
                      trimmed.isEmpty ? null : double.tryParse(trimmed);
                  provider.updateIngredientCost(
                      widget.recipeId, ingredient.id, parsed);
                },
              ),
            ],
            // Results — hidden until Calculate has actually been run at
            // least once (ingredient.newQuantity is null on a fresh
            // recipe), so a card with nothing calculated yet doesn't show
            // a box full of "—" placeholders.
            if (ingredient.newQuantity != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: hasCost
                    ? Row(
                        children: [
                          Expanded(
                            child: _ResultStat(
                              label: IngredientCardLabels.newQuantityStat,
                              value:
                                  '${_formatDisplay(ingredient.newQuantity)} ${ingredient.unit}',
                            ),
                          ),
                          Expanded(
                            child: _ResultStat(
                              label: IngredientCardLabels.newCostStat,
                              value: _formatDisplay(ingredient.newCost,
                                  prefix: currencySymbol),
                            ),
                          ),
                        ],
                      )
                    : _ResultStat(
                        label: IngredientCardLabels.newQuantityStat,
                        value:
                            '${_formatDisplay(ingredient.newQuantity)} ${ingredient.unit}',
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;

  const _ResultStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
