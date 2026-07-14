import 'package:flutter/material.dart';

import '../utils/units.dart';

/// A searchable dropdown for picking a unit of measure, with entries
/// grouped under non-selectable category headers (e.g. "Volume (Imperial)").
///
/// Typing filters the list across all groups, so users don't need to
/// scroll through the full unit list to find e.g. "tbsp".
class UnitDropdownField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String labelText;

  const UnitDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Unit',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final entries = <DropdownMenuEntry<String>>[];
    for (final group in Units.groups) {
      entries.add(
        DropdownMenuEntry(
          value: '__header_${group.category}',
          label: group.category,
          enabled: false,
          style: MenuItemButton.styleFrom(
            textStyle: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      for (final unit in group.units) {
        entries.add(DropdownMenuEntry(value: unit, label: unit));
      }
    }

    return DropdownMenu<String>(
      initialSelection: value,
      dropdownMenuEntries: entries,
      label: Text(labelText),
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      inputDecorationTheme: theme.inputDecorationTheme,
      onSelected: (selected) {
        if (selected == null || selected.startsWith('__header_')) return;
        onChanged(selected);
      },
    );
  }
}
