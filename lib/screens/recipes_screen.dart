import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/domain_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/recipe_provider.dart';
import '../utils/domains.dart';
import '../utils/ui_labels.dart';
import '../widgets/add_recipe_sheet.dart';
import '../widgets/domain_icon.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

/// Sentinel used as the filter chip row's "all domains" selection.
const String _allDomainsFilter = '__all__';

enum _SortOption { oldest, newest, nameAsc, recentlyOpened }

extension on _SortOption {
  String get label => switch (this) {
        _SortOption.oldest => RecipesLabels.sortOldest,
        _SortOption.newest => RecipesLabels.sortNewest,
        _SortOption.nameAsc => RecipesLabels.sortNameAsc,
        _SortOption.recentlyOpened => RecipesLabels.sortRecentlyOpened,
      };
}

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late String _domainFilter;
  _SortOption _sortOption = _SortOption.oldest;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Restore whichever filter chip the user had selected last session —
    // DomainProvider is guaranteed loaded by the time this screen mounts
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

  Future<void> _confirmDeleteRecipe(
      BuildContext context, Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(RecipesLabels.deleteRecipeTitle),
        content: Text(RecipesLabels.deleteRecipeContent(recipe.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(CommonLabels.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(CommonLabels.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    context.read<RecipeProvider>().deleteRecipe(recipe.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(CommonLabels.deleted(recipe.name)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Picks up a domain-filter request from elsewhere (e.g. tapping a
    // domain stat on the Dashboard) — this screen stays alive in
    // HomeShell's IndexedStack, so it wouldn't otherwise notice a filter
    // change made while a different tab was showing.
    final navigationProvider = context.watch<NavigationProvider>();
    final pendingDomainFilter = navigationProvider.pendingDomainFilter;
    if (pendingDomainFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _domainFilter = pendingDomainFilter);
        navigationProvider.consumeDomainFilterRequest();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: RecipesLabels.searchHint,
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleMedium,
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text(RecipesLabels.appBarTitle),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: RecipesLabels.closeSearchTooltip,
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else ...[
            IconButton(
              tooltip: RecipesLabels.searchTooltip,
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
            PopupMenuButton<_SortOption>(
              tooltip: RecipesLabels.sortTooltip,
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
                                    ? RecipesLabels.emptyTitleNoRecipes
                                    : (query.isNotEmpty
                                        ? RecipesLabels
                                            .emptyTitleNoSearchMatch(query)
                                        : RecipesLabels
                                            .emptyTitleNoDomainMatch),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                allRecipes.isEmpty
                                    ? RecipesLabels.emptySubtitleFirstRun
                                    : RecipesLabels.emptySubtitleHasOthers,
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
                              if (allRecipes.isEmpty) ...[
                                const SizedBox(height: 28),
                                const _HowItWorksCard(),
                              ],
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
                                  builder: (_) =>
                                      RecipeDetailScreen(recipeId: recipe.id),
                                ),
                              );
                            },
                            onDelete: () =>
                                _confirmDeleteRecipe(context, recipe),
                            onToggleFavorite: () => context
                                .read<RecipeProvider>()
                                .toggleFavorite(recipe.id),
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
        heroTag: 'recipes_add_recipe_fab',
        onPressed: () => showAddRecipeOptions(context,
            preferredDomainId:
                _domainFilter == _allDomainsFilter ? null : _domainFilter),
        icon: const Icon(Icons.add),
        label: const Text(RecipesLabels.addRecipeFabLabel),
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
    final summary =
        domains.map((d) => '${countsByDomainId[d.id]} ${d.name}').join(' · ');

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
              label: const Text(CommonLabels.all),
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

/// Brief "how this app works" steps shown alongside the empty list, so a
/// first-time user understands the ratio-scaling workflow before adding
/// their first recipe.
class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  static const _steps = [
    (
      Icons.add_circle_outline,
      RecipesLabels.howItWorksStep1Title,
      RecipesLabels.howItWorksStep1Subtitle,
    ),
    (
      Icons.checklist_outlined,
      RecipesLabels.howItWorksStep2Title,
      RecipesLabels.howItWorksStep2Subtitle,
    ),
    (
      Icons.calculate_outlined,
      RecipesLabels.howItWorksStep3Title,
      RecipesLabels.howItWorksStep3Subtitle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(RecipesLabels.howItWorksTitle,
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              for (final (icon, title, subtitle) in _steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

