import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/domain_provider.dart';
import '../providers/recipe_provider.dart';
import '../utils/app_info.dart';
import '../utils/domains.dart';
import '../widgets/domain_icon.dart';
import '../widgets/ratiofy_wordmark.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

/// Sentinel used as the filter chip row's "all domains" selection.
const String _allDomainsFilter = '__all__';

enum _SortOption { oldest, newest, nameAsc, recentlyOpened }

extension on _SortOption {
  String get label => switch (this) {
        _SortOption.oldest => 'Oldest first',
        _SortOption.newest => 'Newest first',
        _SortOption.nameAsc => 'Name (A-Z)',
        _SortOption.recentlyOpened => 'Recently opened',
      };
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late String _domainFilter;
  _SortOption _sortOption = _SortOption.oldest;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Restore whichever filter chip the user had selected last session —
    // DomainProvider is guaranteed loaded by the time the dashboard mounts
    // (the app startup gate waits on it).
    _domainFilter =
        context.read<DomainProvider>().lastFilterDomainId ?? _allDomainsFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setDomainFilter(String id) {
    setState(() => _domainFilter = id);
    context
        .read<DomainProvider>()
        .setLastFilterDomainId(id == _allDomainsFilter ? null : id);
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<Recipe> _applySort(List<Recipe> recipes) {
    final sorted = List<Recipe>.from(recipes);
    switch (_sortOption) {
      case _SortOption.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _SortOption.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortOption.nameAsc:
        sorted.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortOption.recentlyOpened:
        sorted.sort((a, b) => (b.lastOpenedAt ?? b.createdAt)
            .compareTo(a.lastOpenedAt ?? a.createdAt));
        break;
    }
    return sorted;
  }

  Future<void> _showAddRecipeDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final domainProvider = context.read<DomainProvider>();
    final allDomains = domainProvider.allDomains;

    // Prefer whatever the user is currently filtering by; otherwise fall
    // back to the domain they most recently created a recipe in, so the
    // dropdown doesn't always reset to "Food".
    String selectedDomainId;
    if (_domainFilter != _allDomainsFilter &&
        allDomains.any((d) => d.id == _domainFilter)) {
      selectedDomainId = _domainFilter;
    } else {
      final lastUsed = domainProvider.lastUsedDomainId;
      selectedDomainId = (lastUsed != null &&
              allDomains.any((d) => d.id == lastUsed))
          ? lastUsed
          : Domains.defaultId;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedDomain =
                Domains.resolve(selectedDomainId, domainProvider.customDomains
                    .map((d) => d.toDomainDef())
                    .toList());
            return AlertDialog(
              title: const Text('New Recipe'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Recipe name',
                        hintText: selectedDomain.exampleName,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a recipe name';
                        }
                        return null;
                      },
                      onFieldSubmitted: (value) {
                        if (formKey.currentState!.validate()) {
                          Navigator.of(dialogContext).pop({
                            'name': value.trim(),
                            'domainId': selectedDomainId,
                          });
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
                        'name': controller.text.trim(),
                        'domainId': selectedDomainId,
                      });
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    final name = result?['name'];
    if (name != null && name.isNotEmpty && context.mounted) {
      final domainId = result!['domainId']!;
      final provider = context.read<RecipeProvider>();
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

  void _deleteRecipeWithUndo(
      BuildContext context, List<Recipe> allRecipes, Recipe recipe) {
    final provider = context.read<RecipeProvider>();
    final index = allRecipes.indexOf(recipe);
    provider.deleteRecipe(recipe.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${recipe.name}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => provider.restoreRecipe(recipe, index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _isSearching ? kToolbarHeight : kToolbarHeight + 14,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search recipes…',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleMedium,
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RatiofyWordmark(fontSize: 22),
                  Text(
                    AppInfo.tagline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else ...[
            IconButton(
              tooltip: 'Search recipes',
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
            PopupMenuButton<_SortOption>(
              tooltip: 'Sort recipes',
              icon: const Icon(Icons.sort),
              onSelected: (option) => setState(() => _sortOption = option),
              itemBuilder: (context) => [
                for (final option in _SortOption.values)
                  CheckedPopupMenuItem(
                    value: option,
                    checked: option == _sortOption,
                    child: Text(option.label),
                  ),
              ],
            ),
          ],
        ],
      ),
      body: Consumer2<RecipeProvider, DomainProvider>(
        builder: (context, provider, domainProvider, _) {
          final allRecipes = provider.recipes;
          final allDomains = domainProvider.allDomains;

          // Counts per domain, in catalog order, skipping domains with no
          // recipes — feeds both the summary header and the filter chips.
          final countsByDomainId = <String, int>{};
          for (final r in allRecipes) {
            countsByDomainId[r.domainId] =
                (countsByDomainId[r.domainId] ?? 0) + 1;
          }
          final domainsInUse = [
            for (final d in allDomains)
              if (countsByDomainId.containsKey(d.id)) d,
          ];

          var recipes = _domainFilter == _allDomainsFilter
              ? allRecipes
              : allRecipes
                  .where((r) => r.domainId == _domainFilter)
                  .toList(growable: false);

          final query = _searchQuery.trim().toLowerCase();
          if (query.isNotEmpty) {
            recipes = recipes
                .where((r) => r.name.toLowerCase().contains(query))
                .toList(growable: false);
          }

          recipes = _applySort(recipes);

          return Column(
            children: [
              if (allRecipes.isNotEmpty && !_isSearching)
                _DomainSummaryHeader(
                  domains: domainsInUse,
                  countsByDomainId: countsByDomainId,
                ),
              if (domainsInUse.length > 1 && !_isSearching)
                _DomainFilterBar(
                  domains: domainsInUse,
                  selected: _domainFilter,
                  onSelected: _setDomainFilter,
                ),
              Expanded(
                child: recipes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                allRecipes.isEmpty
                                    ? 'No recipes yet'
                                    : (query.isNotEmpty
                                        ? 'No recipes match "$query"'
                                        : 'No recipes in this domain'),
                                style:
                                    Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to add your first recipe.',
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
                        padding: const EdgeInsets.only(top: 12, bottom: 96),
                        itemCount: recipes.length,
                        itemBuilder: (context, index) {
                          final recipe = recipes[index];
                          return RecipeCard(
                            recipe: recipe,
                            domain: domainProvider.resolve(recipe.domainId),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RecipeDetailScreen(
                                      recipeId: recipe.id),
                                ),
                              );
                            },
                            onDelete: () => _deleteRecipeWithUndo(
                                context, allRecipes, recipe),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Distinct per screen so Flutter doesn't try to Hero-morph this FAB
        // into another screen's FAB across a route transition (they'd
        // otherwise share the same default tag and crash on push).
        heroTag: 'dashboard_add_recipe_fab',
        onPressed: () => _showAddRecipeDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe'),
      ),
    );
  }
}

/// Text row summarizing how many recipes fall under each domain in use —
/// e.g. "3 Food · 2 Chemical" — so the count is visible even when the
/// filter chips are collapsed to a single domain.
class _DomainSummaryHeader extends StatelessWidget {
  final List<DomainDef> domains;
  final Map<String, int> countsByDomainId;

  const _DomainSummaryHeader({
    required this.domains,
    required this.countsByDomainId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = domains
        .map((d) => '${countsByDomainId[d.id]} ${d.name}')
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          summary,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Horizontal row of filter chips — "All" plus one per domain currently in
/// use — letting the user narrow the recipe list to a single domain.
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
              selected: selected == _allDomainsFilter,
              onSelected: (_) => onSelected(_allDomainsFilter),
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
