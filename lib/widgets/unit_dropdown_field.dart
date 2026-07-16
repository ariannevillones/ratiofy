import 'package:flutter/material.dart';

import '../utils/ui_labels.dart';
import '../utils/units.dart';

/// A field that looks like a text field but opens a bottom sheet to pick a
/// unit of measure, grouped by category (Count, Volume, Mass, Length,
/// Temperature, Time) in collapsible sections — a flat list of every unit
/// would be too long to scan at a glance.
class UnitDropdownField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String labelText;

  const UnitDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = UnitPickerLabels.defaultFieldLabel,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UnitPickerSheet(value: value),
    );
    if (selected != null && selected != value) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPicker(context),
      child: InputDecorator(
        decoration: InputDecoration(labelText: labelText),
        isEmpty: false,
        child: Row(
          children: [
            Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Icon representing a unit category — shown as each group's leading icon
/// in the picker sheet.
IconData _iconForCategory(String category) {
  switch (category) {
    case 'Count':
      return Icons.inventory_2_outlined;
    case 'Volume (SI)':
    case 'Volume (Imperial)':
      return Icons.water_drop_outlined;
    case 'Mass (SI)':
    case 'Mass (Imperial)':
      return Icons.scale_outlined;
    case 'Length (SI)':
    case 'Length (Imperial)':
      return Icons.straighten_outlined;
    case 'Temperature':
      return Icons.thermostat_outlined;
    case 'Time':
      return Icons.schedule_outlined;
    default:
      return Icons.category_outlined;
  }
}

/// Bottom sheet listing every unit, grouped by category into collapsible
/// [ExpansionTile]s (only the group containing the current value starts
/// expanded) with a search field to filter across all groups at once.
class _UnitPickerSheet extends StatefulWidget {
  final String value;

  const _UnitPickerSheet({required this.value});

  @override
  State<_UnitPickerSheet> createState() => _UnitPickerSheetState();
}

class _UnitPickerSheetState extends State<_UnitPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _matchingUnits(UnitGroup group, String query) {
    if (query.isEmpty) return group.units;
    return group.units.where((u) => u.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchQuery.trim().toLowerCase();

    final visibleGroups = query.isEmpty
        ? Units.groups
        : Units.groups
            .where((g) => _matchingUnits(g, query).isNotEmpty)
            .toList();

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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(UnitPickerLabels.pickerTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: UnitPickerLabels.searchHint,
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
              child: visibleGroups.isEmpty
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
                              UnitPickerLabels.noUnitsMatch(query),
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
                          ExpansionTile(
                            initiallyExpanded: query.isNotEmpty ||
                                group.units.contains(widget.value),
                            leading: Icon(
                              _iconForCategory(group.category),
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(group.category,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            children: [
                              for (final unit in _matchingUnits(group, query))
                                ListTile(
                                  title: Text(unit),
                                  trailing: unit == widget.value
                                      ? Icon(Icons.check,
                                          color: theme.colorScheme.primary)
                                      : null,
                                  onTap: () => Navigator.of(context).pop(unit),
                                ),
                            ],
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
