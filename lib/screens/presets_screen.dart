import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/preset.dart';
import '../providers/domain_provider.dart';
import '../providers/preset_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/domains.dart';
import '../utils/units.dart';
import '../widgets/domain_icon.dart';
import '../widgets/unit_dropdown_field.dart';

/// Sentinel used in domain-picker dropdowns for "no domain" (available
/// everywhere) — Dart's Dropdown widgets don't accept a null item value.
const String _allDomainsSentinel = '__all__';

/// Whether [group]'s own label matches [query] (already lowercased/trimmed).
/// The always-present Ungrouped group has no real `label` field consumers
/// should match against, so it's matched against the word "ungrouped".
bool _groupLabelMatches(PresetGroup group, String query, bool isUngrouped) {
  if (query.isEmpty) return true;
  final label = isUngrouped ? 'ungrouped' : group.label.toLowerCase();
  return label.contains(query);
}

/// Ingredients within [group] whose name matches [query]. Empty query
/// matches everything.
List<PresetIngredient> _matchingIngredients(PresetGroup group, String query) {
  if (query.isEmpty) return group.ingredients;
  return group.ingredients
      .where((i) => i.name.toLowerCase().contains(query))
      .toList();
}

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _domainFilter = _allDomainsSentinel;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _showAddGroupDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final allDomains = context.read<DomainProvider>().allDomains;
    String selectedDomainId = _allDomainsSentinel;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Preset Group'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Group label',
                    hintText: 'e.g. Filipino Savory Staples',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Please enter a label'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDomainId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Domain (optional)'),
                  items: [
                    const DropdownMenuItem(
                      value: _allDomainsSentinel,
                      child: Text('All domains'),
                    ),
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
              ],
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
                  Navigator.of(dialogContext).pop({
                    'label': controller.text.trim(),
                    'domainId': selectedDomainId,
                  });
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    final label = result?['label'];
    if (label != null && label.isNotEmpty && context.mounted) {
      final domainId = result!['domainId'];
      context.read<PresetProvider>().addGroup(
            label,
            domainId:
                domainId == _allDomainsSentinel ? null : domainId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search ingredients…',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleMedium,
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text('Ingredients'),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else
            IconButton(
              tooltip: 'Search ingredients',
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
        ],
      ),
      body: Consumer2<PresetProvider, DomainProvider>(
        builder: (context, provider, domainProvider, _) {
          final groups = provider.groups;
          final query = _searchQuery.trim().toLowerCase();

          // Domains that have at least one group explicitly scoped to
          // them — feeds the filter chip row, mirroring the Recipes tab.
          final domainsInUse = [
            for (final d in domainProvider.allDomains)
              if (groups.any((g) => g.domainId == d.id)) d,
          ];

          final domainFiltered = _domainFilter == _allDomainsSentinel
              ? groups
              : groups
                  .where((g) =>
                      g.domainId == null || g.domainId == _domainFilter)
                  .toList();

          final visibleGroups = query.isEmpty
              ? domainFiltered
              : domainFiltered.where((g) {
                  final isUngrouped = g.id == PresetProvider.ungroupedGroupId;
                  return _groupLabelMatches(g, query, isUngrouped) ||
                      _matchingIngredients(g, query).isNotEmpty;
                }).toList();

          return Column(
            children: [
              if (domainsInUse.length > 1 && !_isSearching)
                _DomainFilterBar(
                  domains: domainsInUse,
                  selected: _domainFilter,
                  onSelected: (id) => setState(() => _domainFilter = id),
                ),
              Expanded(
                child: visibleGroups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 12),
                              Text('No ingredients match "$query"',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        itemCount: visibleGroups.length,
                        itemBuilder: (context, index) => _PresetGroupCard(
                          group: visibleGroups[index],
                          searchQuery: query,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'presets_new_group_fab',
        onPressed: () => _showAddGroupDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
    );
  }
}

class _PresetGroupCard extends StatefulWidget {
  final PresetGroup group;

  /// Lowercased, trimmed search query from the Ingredients page's search
  /// bar. Empty means "not searching".
  final String searchQuery;

  const _PresetGroupCard({required this.group, this.searchQuery = ''});

  @override
  State<_PresetGroupCard> createState() => _PresetGroupCardState();
}

class _PresetGroupCardState extends State<_PresetGroupCard> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  PresetGroup get group => widget.group;

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _showRenameGroupDialog(BuildContext context) async {
    final controller = TextEditingController(text: group.label);
    final formKey = GlobalKey<FormState>();

    final newLabel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Group'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Group label'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Please enter a label'
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

    if (newLabel != null && newLabel.isNotEmpty && context.mounted) {
      context.read<PresetProvider>().renameGroup(group.id, newLabel);
    }
  }

  Future<void> _showChangeDomainDialog(BuildContext context) async {
    final domainProvider = context.read<DomainProvider>();
    final allDomains = domainProvider.allDomains;
    String selectedDomainId = group.domainId ?? _allDomainsSentinel;

    final newDomainId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Group Domain'),
          content: SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              initialValue: selectedDomainId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Domain'),
              items: [
                const DropdownMenuItem(
                  value: _allDomainsSentinel,
                  child: Text('All domains'),
                ),
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
      context.read<PresetProvider>().setGroupDomain(
          group.id, newDomainId == _allDomainsSentinel ? null : newDomainId);
    }
  }

  Future<void> _confirmDeleteGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
            '"${group.label}" and its ${group.ingredients.length} preset ingredient(s) will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<PresetProvider>().deleteGroup(group.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete selected ingredients?'),
        content: Text(
            '$count ingredient(s) will be removed from "${group.label}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<PresetProvider>();
      for (final id in _selectedIds) {
        provider.deletePresetIngredient(group.id, id);
      }
      _exitSelectionMode();
    }
  }

  Future<void> _showIngredientDialog(BuildContext context,
      {PresetIngredient? existing}) async {
    final currencySymbol = context.read<SettingsProvider>().currencySymbol;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final quantityController = TextEditingController(
        text: existing != null ? _formatForEditing(existing.quantity) : '0');
    final costController = TextEditingController(
        text: existing?.cost != null
            ? _formatForEditing(existing!.cost!)
            : '');
    String unit = existing?.unit ?? Units.defaultUnit;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null
                  ? 'New Preset Ingredient'
                  : 'Edit Preset Ingredient'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Ingredient name',
                          hintText: 'e.g. Garlic',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Please enter a name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: quantityController,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Default quantity'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: UnitDropdownField(
                              value: unit,
                              onChanged: (value) =>
                                  setState(() => unit = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: costController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Default cost (optional)',
                          prefixText: '$currencySymbol ',
                        ),
                      ),
                    ],
                  ),
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
                      final qty = double.tryParse(quantityController.text) ?? 0;
                      final costText = costController.text.trim();
                      final cost =
                          costText.isEmpty ? null : double.tryParse(costText);
                      Navigator.of(dialogContext).pop({
                        'name': nameController.text.trim(),
                        'unit': unit,
                        'quantity': qty,
                        'cost': cost,
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      final provider = context.read<PresetProvider>();
      if (existing == null) {
        provider.addPresetIngredient(
          group.id,
          name: result['name'] as String,
          unit: result['unit'] as String,
          quantity: result['quantity'] as double,
          cost: result['cost'] as double?,
        );
      } else {
        provider.updatePresetIngredient(
          group.id,
          existing.id,
          name: result['name'] as String,
          unit: result['unit'] as String,
          quantity: result['quantity'] as double,
          cost: result['cost'] as double?,
          clearCost: result['cost'] == null,
        );
      }
    }
  }

  String _formatForEditing(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  bool get _isUngrouped => group.id == PresetProvider.ungroupedGroupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final domainProvider = context.watch<DomainProvider>();

    // While searching, show every ingredient if the group's own label
    // matched (browsing that whole category), otherwise just the matches.
    final groupLabelMatches =
        _groupLabelMatches(group, widget.searchQuery, _isUngrouped);
    final displayIngredients = groupLabelMatches
        ? group.ingredients
        : _matchingIngredients(group, widget.searchQuery);

    final hasIngredients = displayIngredients.isNotEmpty;
    final allSelected =
        hasIngredients && _selectedIds.length == displayIngredients.length;
    final scopedDomain =
        group.domainId != null ? domainProvider.resolve(group.domainId!) : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading:
            scopedDomain != null ? DomainIconBadge(domain: scopedDomain) : null,
        title: Text(
          _isUngrouped ? 'Ungrouped' : group.label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${_isUngrouped ? (displayIngredients.length == 1 ? '1 ingredient without a group' : '${displayIngredients.length} ingredients without a group') : (displayIngredients.length == 1 ? '1 ingredient' : '${displayIngredients.length} ingredients')}'
          '${widget.searchQuery.isNotEmpty && !groupLabelMatches ? ' matching' : ''}'
          '${scopedDomain != null ? ' · ${scopedDomain.name}' : ''}',
        ),
        trailing: _selectionMode
            ? TextButton(
                onPressed: _exitSelectionMode,
                child: const Text('Done'),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasIngredients)
                    IconButton(
                      tooltip: 'Select ingredients',
                      icon: const Icon(Icons.checklist_outlined),
                      onPressed: () =>
                          setState(() => _selectionMode = true),
                    ),
                  if (!_isUngrouped)
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'rename') {
                          _showRenameGroupDialog(context);
                        }
                        if (action == 'domain') {
                          _showChangeDomainDialog(context);
                        }
                        if (action == 'delete') _confirmDeleteGroup(context);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: 'rename', child: Text('Rename group')),
                        PopupMenuItem(
                            value: 'domain', child: Text('Change domain')),
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete group')),
                      ],
                    ),
                ],
              ),
        children: [
          if (_selectionMode && hasIngredients)
            CheckboxListTile(
              value: allSelected,
              title: const Text('Select all'),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedIds
                      ..clear()
                      ..addAll(displayIngredients.map((i) => i.id));
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
          for (final ingredient in displayIngredients)
            _selectionMode
                ? CheckboxListTile(
                    value: _selectedIds.contains(ingredient.id),
                    title: Text(ingredient.name),
                    subtitle: Text(
                      '${_formatForEditing(ingredient.quantity)} ${ingredient.unit}'
                      '${ingredient.cost != null ? ', $currencySymbol${ingredient.cost!.toStringAsFixed(2)}' : ''}',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(ingredient.id);
                        } else {
                          _selectedIds.remove(ingredient.id);
                        }
                      });
                    },
                  )
                : ListTile(
                    title: Text(ingredient.name),
                    subtitle: Text(
                      '${_formatForEditing(ingredient.quantity)} ${ingredient.unit}'
                      '${ingredient.cost != null ? ', $currencySymbol${ingredient.cost!.toStringAsFixed(2)}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showIngredientDialog(context,
                              existing: ingredient),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => context
                              .read<PresetProvider>()
                              .deletePresetIngredient(group.id, ingredient.id),
                        ),
                      ],
                    ),
                  ),
          if (_selectionMode && _selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _confirmDeleteSelected(context),
                  icon: const Icon(Icons.delete_outline),
                  label: Text('Delete Selected (${_selectedIds.length})'),
                ),
              ),
            ),
          if (!_selectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showIngredientDialog(context),
                  icon: const Icon(Icons.add),
                  label: Text(_isUngrouped
                      ? 'Add ingredient'
                      : 'Add ingredient to group'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal row of filter chips — "All" plus one per domain that has at
/// least one group scoped to it — letting the user narrow the group list
/// to a single domain. Mirrors the Recipes tab's domain filter bar.
class _DomainFilterBar extends StatelessWidget {
  final List<DomainDef> domains;
  final String selected;
  final ValueChanged<String> onSelected;

  const _DomainFilterBar({
    required this.domains,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == _allDomainsSentinel,
              onSelected: (_) => onSelected(_allDomainsSentinel),
            ),
          ),
          for (final domain in domains)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                avatar: DomainIconBadge(domain: domain, size: 18),
                label: Text(domain.name),
                selected: selected == domain.id,
                onSelected: (_) => onSelected(domain.id),
              ),
            ),
        ],
      ),
    );
  }
}
