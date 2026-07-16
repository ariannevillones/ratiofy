import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/preset.dart';
import '../providers/domain_provider.dart';
import '../providers/preset_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/presets_screen.dart';
import '../utils/ui_labels.dart';
import 'domain_icon.dart';

/// Bottom sheet that lets the user pick one or more preset ingredients
/// (across any of their configured groups) to add to a recipe in one go.
class PresetPickerSheet extends StatefulWidget {
  final String recipeId;

  const PresetPickerSheet({super.key, required this.recipeId});

  @override
  State<PresetPickerSheet> createState() => _PresetPickerSheetState();
}

class _PresetPickerSheetState extends State<PresetPickerSheet> {
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  /// Ingredients within [group] whose name matches [query]. Empty query
  /// matches everything.
  List<PresetIngredient> _matchingIngredients(PresetGroup group, String query) {
    if (query.isEmpty) return group.ingredients;
    return group.ingredients
        .where((i) => i.name.toLowerCase().contains(query))
        .toList();
  }

  void _addSelected(BuildContext context, List<PresetGroup> groups) {
    final recipeProvider = context.read<RecipeProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final selectedPresets = <PresetIngredient>[
      for (final group in groups)
        for (final ingredient in group.ingredients)
          if (_selectedIds.contains(ingredient.id)) ingredient,
    ];

    var addedCount = 0;
    var hitLimit = false;
    for (final preset in selectedPresets) {
      final result =
          recipeProvider.addIngredientFromPreset(widget.recipeId, preset);
      if (result == AddIngredientResult.recipeFull) {
        hitLimit = true;
        break;
      }
      addedCount++;
    }

    Navigator.of(context).pop();

    if (addedCount > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(hitLimit
              ? PresetPickerLabels.addedCount(addedCount)
              : PresetPickerLabels.addedCountNoLimit(addedCount)),
        ),
      );
    } else if (hitLimit) {
      messenger.showSnackBar(
        const SnackBar(content: Text(PresetPickerLabels.recipeAlreadyFull)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final presetProvider = context.watch<PresetProvider>();
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final domainProvider = context.watch<DomainProvider>();
    final recipe = context.watch<RecipeProvider>().getRecipe(widget.recipeId);
    final recipeDomainId = recipe?.domainId;

    // Skip empty groups, and groups scoped to a *different* domain than
    // this recipe — this is a picker, not the management screen, so only
    // relevant, populated groups belong here. Domain-matching groups
    // (including the always-visible unscoped ones) come first.
    final groups = presetProvider.groups
        .where((g) => g.ingredients.isNotEmpty)
        .where((g) => g.domainId == null || g.domainId == recipeDomainId)
        .toList()
      ..sort((a, b) {
        final aMatches = a.domainId != null ? 0 : 1;
        final bMatches = b.domainId != null ? 0 : 1;
        return aMatches.compareTo(bMatches);
      });
    final theme = Theme.of(context);

    final query = _searchQuery.trim().toLowerCase();
    final visibleGroups = query.isEmpty
        ? groups
        : groups.where((g) {
            final labelMatches = g.label.toLowerCase().contains(query);
            return labelMatches || _matchingIngredients(g, query).isNotEmpty;
          }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(PresetPickerLabels.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PresetsScreen()),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text(PresetPickerLabels.manage),
                  ),
                ],
              ),
            ),
            if (groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: PresetPickerLabels.searchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: CommonLabels.clearSearch,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              PresetPickerLabels.noPresetsConfigured,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              PresetPickerLabels.noPresetsHint,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  : visibleGroups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off,
                                    size: 48, color: theme.colorScheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  PresetPickerLabels.noIngredientsMatch(query),
                                  style: theme.textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 8),
                          children: [
                            for (final group in visibleGroups)
                              Builder(builder: (context) {
                                final groupLabelMatches =
                                    group.label.toLowerCase().contains(query);
                                final displayIngredients = groupLabelMatches
                                    ? group.ingredients
                                    : _matchingIngredients(group, query);
                                return ExpansionTile(
                                  initiallyExpanded: true,
                                  leading: group.domainId != null
                                      ? DomainIconBadge(
                                          domain: domainProvider
                                              .resolve(group.domainId!),
                                          size: 26,
                                        )
                                      : null,
                                  title: Text(group.label,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  trailing: displayIngredients.isEmpty
                                      ? null
                                      : _GroupSelectAllCheckbox(
                                          allSelected: displayIngredients.every(
                                              (i) =>
                                                  _selectedIds.contains(i.id)),
                                          onChanged: (selectAll) {
                                            setState(() {
                                              if (selectAll) {
                                                _selectedIds.addAll(
                                                    displayIngredients
                                                        .map((i) => i.id));
                                              } else {
                                                _selectedIds.removeAll(
                                                    displayIngredients
                                                        .map((i) => i.id));
                                              }
                                            });
                                          },
                                        ),
                                  children: [
                                    for (final ingredient in displayIngredients)
                                      CheckboxListTile(
                                        value: _selectedIds
                                            .contains(ingredient.id),
                                        title: Text(ingredient.name),
                                        subtitle: Text(
                                          '${_formatQuantity(ingredient.quantity)} ${ingredient.unit}'
                                          '${ingredient.cost != null ? ', $currencySymbol${ingredient.cost!.toStringAsFixed(2)}' : ''}',
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        onChanged: (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedIds.add(ingredient.id);
                                            } else {
                                              _selectedIds
                                                  .remove(ingredient.id);
                                            }
                                          });
                                        },
                                      ),
                                  ],
                                );
                              }),
                          ],
                        ),
            ),
            if (groups.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => _addSelected(context, groups),
                      child: Text(_selectedIds.isEmpty
                          ? PresetPickerLabels.selectIngredientsToAdd
                          : PresetPickerLabels.addSelected(_selectedIds.length)),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Small "select all" control shown as the trailing widget of each group's
/// [ExpansionTile] in the preset picker, so the user can grab an entire
/// group in one tap instead of checking each ingredient individually.
class _GroupSelectAllCheckbox extends StatelessWidget {
  final bool allSelected;
  final ValueChanged<bool> onChanged;

  const _GroupSelectAllCheckbox({
    required this.allSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(CommonLabels.all, style: Theme.of(context).textTheme.labelSmall),
        Checkbox(
          value: allSelected,
          onChanged: (checked) => onChanged(checked ?? false),
        ),
      ],
    );
  }
}
