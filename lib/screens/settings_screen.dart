import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../models/domain.dart';
import '../providers/domain_provider.dart';
import '../providers/preset_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_info.dart';
import '../utils/currencies.dart';
import '../utils/domains.dart';
import '../utils/units.dart';
import '../widgets/domain_icon.dart';
import '../widgets/ratiofy_wordmark.dart';
import '../widgets/unit_dropdown_field.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showAddDomainDialog(BuildContext context) async {
    final controller = TextEditingController();
    final extraFieldController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String iconKey = Domains.defaultIconKey;
    Color color = Domains.colorChoices.first;
    String defaultUnit = Units.defaultUnit;
    bool costVisible = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Domain'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Form(
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
                        labelText: 'Domain name',
                        hintText: 'e.g. Candles, Aquarium Mix',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Please enter a name'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    Text('Icon', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in Domains.iconChoices.entries)
                          _IconChoice(
                            icon: entry.value,
                            color: color,
                            selected: iconKey == entry.key,
                            onTap: () =>
                                setDialogState(() => iconKey = entry.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Color', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final choice in Domains.colorChoices)
                          _ColorChoice(
                            color: choice,
                            selected: color.toARGB32() == choice.toARGB32(),
                            onTap: () => setDialogState(() => color = choice),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    UnitDropdownField(
                      value: defaultUnit,
                      labelText: 'Default unit for new ingredients',
                      onChanged: (value) =>
                          setDialogState(() => defaultUnit = value),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show cost field'),
                      subtitle: const Text(
                          'Turn off for domains where price isn\'t relevant'),
                      value: costVisible,
                      onChanged: (value) =>
                          setDialogState(() => costVisible = value),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: extraFieldController,
                      decoration: const InputDecoration(
                        labelText: 'Extra field (optional)',
                        hintText: 'e.g. CAS Number, INCI Name, Batch code',
                      ),
                    ),
                  ],
                ),
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
                  Navigator.of(dialogContext).pop({
                    'name': controller.text.trim(),
                    'iconKey': iconKey,
                    'colorValue': color.toARGB32(),
                    'defaultUnit': defaultUnit,
                    'costVisible': costVisible,
                    'extraFieldLabel': extraFieldController.text.trim(),
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null && context.mounted) {
      context.read<DomainProvider>().addDomain(
            result['name'] as String,
            iconKey: result['iconKey'] as String,
            colorValue: result['colorValue'] as int,
            defaultUnit: result['defaultUnit'] as String,
            costVisible: result['costVisible'] as bool,
            extraFieldLabel: result['extraFieldLabel'] as String,
          );
    }
  }

  Future<void> _showExportDialog(BuildContext context) async {
    final data = {
      'version': 1,
      'recipes': context.read<RecipeProvider>().exportAll(),
      'presets': context.read<PresetProvider>().exportAll(),
      'domains': context.read<DomainProvider>().exportAll(),
      'settings': context.read<SettingsProvider>().exportAll(),
    };
    final text = const JsonEncoder.withIndent('  ').convert(data);

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export Backup'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();

    final pasted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Backup'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 10,
            minLines: 4,
            decoration: const InputDecoration(
              hintText: 'Paste a backup exported from this app',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (pasted == null || pasted.trim().isEmpty || !context.mounted) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(pasted) as Map<String, dynamic>;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('That doesn\'t look like a valid backup.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
            'Importing will replace every recipe, preset, and domain currently in the app. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final recipeProvider = context.read<RecipeProvider>();
    final presetProvider = context.read<PresetProvider>();
    final domainProvider = context.read<DomainProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (data['recipes'] is Map<String, dynamic>) {
      await recipeProvider.importAll(data['recipes'] as Map<String, dynamic>);
    }
    if (data['presets'] is Map<String, dynamic>) {
      await presetProvider.importAll(data['presets'] as Map<String, dynamic>);
    }
    if (data['domains'] is Map<String, dynamic>) {
      await domainProvider.importAll(data['domains'] as Map<String, dynamic>);
    }
    if (data['settings'] is Map<String, dynamic>) {
      await settingsProvider
          .importAll(data['settings'] as Map<String, dynamic>);
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Backup imported.')),
    );
  }

  Future<void> _confirmDeleteDomain(
      BuildContext context, CustomDomain domain) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete domain?'),
        content: Text(
            '"${domain.name}" will be removed. Recipes already using it will fall back to "Other".'),
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
      context.read<DomainProvider>().deleteDomain(domain.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final domainProvider = context.watch<DomainProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Theme',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how Ratiofy looks, or follow your device setting.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) => context
                .read<SettingsProvider>()
                .setThemeMode(selection.first),
          ),
          const SizedBox(height: 24),
          Text(
            'Currency',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Used for all ingredient cost fields across every recipe.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButtonFormField<String>(
                initialValue: settings.currencyCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Default currency',
                  border: InputBorder.none,
                ),
                items: [
                  for (final currency in Currencies.all)
                    DropdownMenuItem(
                      value: currency.code,
                      child: Text(
                          '${currency.symbol}  ${currency.code} — ${currency.name}'),
                    ),
                ],
                onChanged: (code) {
                  if (code != null) {
                    context.read<SettingsProvider>().setCurrencyCode(code);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Domains',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Categorize recipes by domain — Food, Chemical, Cosmetics, and Other are built in. Add your own for anything else.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final domain in Domains.builtIn)
                  ListTile(
                    leading: DomainIconBadge(domain: domain),
                    title: Text(domain.name),
                    trailing: const Text('Built-in'),
                  ),
                if (domainProvider.customDomains.isNotEmpty)
                  const Divider(height: 1),
                for (final domain in domainProvider.customDomains)
                  ListTile(
                    leading: DomainIconBadge(domain: domain.toDomainDef()),
                    title: Text(domain.name),
                    trailing: IconButton(
                      tooltip: 'Delete domain',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeleteDomain(context, domain),
                    ),
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add domain'),
                  onTap: () => _showAddDomainDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Backup & Restore',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Everything is stored only on this device. Export a backup before reinstalling or switching devices.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_outlined),
                  title: const Text('Export all data'),
                  subtitle: const Text('Copy a backup to your clipboard'),
                  onTap: () => _showExportDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Import backup'),
                  subtitle: const Text('Replaces all current data'),
                  onTap: () => _showImportDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'About',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const RatiofyWordmark(fontSize: 26),
                      const SizedBox(width: 8),
                      Text(
                        'v${AppInfo.version}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(AppInfo.tagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 12),
                  Text(AppInfo.description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: AppInfo.name,
                        applicationVersion: AppInfo.version,
                      ),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Open-source licenses'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? color.withValues(alpha: 0.22)
              : theme.colorScheme.surfaceContainerHighest,
          border: selected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? color : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface, width: 2)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
