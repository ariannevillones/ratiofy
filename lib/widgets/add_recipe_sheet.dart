import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/domain_provider.dart';
import '../providers/recipe_provider.dart';
import '../screens/recipe_detail_screen.dart';
import '../utils/domains.dart';
import '../utils/recipe_templates.dart';
import '../utils/ui_labels.dart';
import 'action_option_tile.dart';
import 'domain_icon.dart';

/// The next unused "Recipe N" name — used when the user adds a blank
/// recipe without typing a name, so "Add" always works immediately
/// instead of blocking on a required field.
String _nextGenericRecipeName(List<Recipe> recipes) {
  final existingNames =
      recipes.map((r) => r.name.trim().toLowerCase()).toSet();
  var n = 1;
  while (existingNames.contains('recipe $n')) {
    n++;
  }
  return 'Recipe $n';
}

Future<void> _showAddRecipeDialog(
    BuildContext context, String? preferredDomainId) async {
  final controller = TextEditingController();
  final domainProvider = context.read<DomainProvider>();
  final allDomains = domainProvider.allDomains;

  // Prefer the caller's preferred domain (e.g. the Recipes tab's current
  // filter); otherwise fall back to the domain most recently used, so the
  // dropdown doesn't always reset to "Food".
  String selectedDomainId;
  if (preferredDomainId != null &&
      allDomains.any((d) => d.id == preferredDomainId)) {
    selectedDomainId = preferredDomainId;
  } else {
    final lastUsed = domainProvider.lastUsedDomainId;
    selectedDomainId =
        (lastUsed != null && allDomains.any((d) => d.id == lastUsed))
            ? lastUsed
            : Domains.defaultId;
  }

  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedDomain = Domains.resolve(
              selectedDomainId,
              domainProvider.customDomains.map((d) => d.toDomainDef()).toList());
          return AlertDialog(
            title: const Text(RecipesLabels.newRecipeDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
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
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: RecipesLabels.recipeNameLabel,
                    hintText: selectedDomain.exampleName,
                  ),
                  onSubmitted: (value) {
                    Navigator.of(dialogContext).pop({
                      'name': value.trim(),
                      'domainId': selectedDomainId,
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(CommonLabels.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop({
                    'name': controller.text.trim(),
                    'domainId': selectedDomainId,
                  });
                },
                child: const Text(CommonLabels.add),
              ),
            ],
          );
        },
      );
    },
  );

  final domainId = result?['domainId'];
  if (domainId != null && context.mounted) {
    final provider = context.read<RecipeProvider>();
    final name = result!['name']!.isEmpty
        ? _nextGenericRecipeName(provider.recipes)
        : result['name']!;
    final recipe = provider.addRecipe(name, domainId: domainId);
    await domainProvider.setLastUsedDomainId(domainId);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
        ),
      );
    }
  }
}

Future<void> _showTemplatePicker(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TemplatePickerSheet(),
  );
}

/// Shows the "Blank recipe/formula" vs "From Presaved Recipes/Formulas"
/// bottom sheet and drives whichever flow the user picks. Shared by the
/// Recipes tab's FAB and the Dashboard's quick-add shortcut, so both stay
/// in sync automatically. [preferredDomainId] biases the blank-recipe
/// dialog's default domain (e.g. the Recipes tab's current filter);
/// pass null to just fall back to the last-used domain.
Future<void> showAddRecipeOptions(BuildContext context,
    {String? preferredDomainId}) async {
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
                RecipesLabels.addRecipeFabLabel,
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
              title: RecipesLabels.addOptionsBlankTitle,
              subtitle: RecipesLabels.addOptionsBlankSubtitle,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showAddRecipeDialog(context, preferredDomainId);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: ActionOptionTile(
              icon: Icons.bookmark_outline,
              title: RecipesLabels.addOptionsTemplateTitle,
              subtitle: RecipesLabels.addOptionsTemplateSubtitle,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showTemplatePicker(context);
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

/// Bottom sheet for picking a presaved recipe/formula template — styled to
/// match [PresetPickerSheet] (search field, collapsible per-group sections)
/// even though picking a template is a single tap-to-create action rather
/// than a multi-select-then-add one.
class _TemplatePickerSheet extends StatefulWidget {
  const _TemplatePickerSheet();

  @override
  State<_TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<_TemplatePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecipeTemplate> _matchingTemplates(String domainId, String query) {
    final templates = RecipeTemplates.forDomain(domainId);
    if (query.isEmpty) return templates;
    return templates
        .where((t) => t.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _selectTemplate(
      BuildContext context, RecipeTemplate template) async {
    final provider = context.read<RecipeProvider>();
    final domainProvider = context.read<DomainProvider>();
    final recipe = provider.addRecipeFromTemplate(template);
    await domainProvider.setLastUsedDomainId(template.domainId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchQuery.trim().toLowerCase();

    final domainsWithTemplates = [
      for (final domain in Domains.builtIn)
        if (RecipeTemplates.forDomain(domain.id).isNotEmpty) domain,
    ];
    final visibleDomains = query.isEmpty
        ? domainsWithTemplates
        : domainsWithTemplates
            .where((d) => _matchingTemplates(d.id, query).isNotEmpty)
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
                child: Text(RecipesLabels.templatePickerTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: RecipesLabels.templateSearchHint,
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
              child: visibleDomains.isEmpty
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
                              RecipesLabels.templateNoMatch(query),
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
                        for (final domain in visibleDomains)
                          ExpansionTile(
                            initiallyExpanded: true,
                            leading: DomainIconBadge(domain: domain, size: 26),
                            title: Text(domain.name,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            children: [
                              for (final template
                                  in _matchingTemplates(domain.id, query))
                                ListTile(
                                  title: Text(template.name),
                                  subtitle: Text(
                                      '${template.ingredients.length} ingredients'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      _selectTemplate(context, template),
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
