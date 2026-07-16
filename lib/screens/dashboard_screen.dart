import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/domain_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_info.dart';
import '../utils/domains.dart';
import '../utils/image_display.dart';
import '../utils/ui_labels.dart';
import '../widgets/add_recipe_sheet.dart';
import '../widgets/domain_icon.dart';
import '../widgets/ratiofy_logo.dart';
import '../widgets/recipe_card.dart';
import 'quick_calculator_screen.dart';
import 'recipe_detail_screen.dart';

/// How many of the most-recently-added recipes (and, separately,
/// favorites) to show in each carousel.
const int _carouselLimit = 10;

/// App home screen: a summary of what's in the app (recipe/ingredient/cost
/// counts, tappable domain breakdown), a "continue where you left off"
/// shortcut, quick actions (Add Recipe, Quick Ratio Calculator), and
/// horizontal carousels of favorited and recently added recipes. Also has
/// its own recipe search (by name, across every domain) for quick lookup
/// without switching to the Recipes tab. The full, filterable/sortable
/// recipe list still lives on its own "Recipes/Formulas" tab.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _isSearching ? kToolbarHeight : kToolbarHeight + 14,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: RecipesLabels.searchHint,
                  border: InputBorder.none,
                ),
                style: theme.textTheme.titleMedium,
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RatiofyLogo(iconSize: 26, fontSize: 20),
                  Text(
                    AppInfo.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: RecipesLabels.closeSearchTooltip,
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else
            IconButton(
              tooltip: RecipesLabels.searchTooltip,
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
        ],
      ),
      body: Consumer3<RecipeProvider, DomainProvider, SettingsProvider>(
        builder: (context, recipeProvider, domainProvider, settings, _) {
          final recipes = recipeProvider.recipes;
          final query = _searchQuery.trim().toLowerCase();

          if (_isSearching && query.isNotEmpty) {
            final matches = recipes
                .where((r) => r.name.toLowerCase().contains(query))
                .toList();
            return matches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        CommonLabels.noMatchFor('recipes', query),
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 12, bottom: 96),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final recipe = matches[index];
                      return RecipeCard(
                        recipe: recipe,
                        domain: domainProvider.resolve(recipe.domainId),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RecipeDetailScreen(recipeId: recipe.id),
                          ),
                        ),
                        onDelete: () => _confirmDeleteRecipe(context, recipe),
                        onToggleFavorite: () => recipeProvider
                            .toggleFavorite(recipe.id),
                      );
                    },
                  );
          }

          final countsByDomainId = <String, int>{};
          var totalIngredients = 0;
          double totalCost = 0;
          var costRecipeCount = 0;
          for (final r in recipes) {
            countsByDomainId[r.domainId] =
                (countsByDomainId[r.domainId] ?? 0) + 1;
            totalIngredients += r.ingredients.length;
            final cost = r.totalCost;
            if (cost != null) {
              totalCost += cost;
              costRecipeCount++;
            }
          }
          final domainsInUse = [
            for (final d in domainProvider.allDomains)
              if (countsByDomainId.containsKey(d.id)) d,
          ];

          final recent = List<Recipe>.from(recipes)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final recentTop = recent.take(_carouselLimit).toList();

          final favorites = recipes.where((r) => r.isFavorite).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final favoritesTop = favorites.take(_carouselLimit).toList();

          Recipe? continueRecipe;
          for (final r in recipes) {
            if (r.lastOpenedAt == null) continue;
            if (continueRecipe == null ||
                r.lastOpenedAt!.isAfter(continueRecipe.lastOpenedAt!)) {
              continueRecipe = r;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SummaryCard(
                recipeCount: recipes.length,
                ingredientCount: totalIngredients,
                totalCost: costRecipeCount > 0 ? totalCost : null,
                currencySymbol: settings.currencySymbol,
                domainsInUse: domainsInUse,
                countsByDomainId: countsByDomainId,
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              Text(
                AppInfo.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MenuIconAction(
                      icon: Icons.add_circle_outline,
                      label: DashboardLabels.addRecipeCardTitle,
                      onTap: () => showAddRecipeOptions(context),
                    ),
                  ),
                  Expanded(
                    child: _MenuIconAction(
                      icon: Icons.calculate_outlined,
                      label: DashboardLabels.quickCalculatorTitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QuickCalculatorScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (continueRecipe != null) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Text(
                  DashboardLabels.continueLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                RecipeCard(
                  recipe: continueRecipe,
                  domain: domainProvider.resolve(continueRecipe.domainId),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RecipeDetailScreen(recipeId: continueRecipe!.id),
                    ),
                  ),
                  onDelete: () =>
                      _confirmDeleteRecipe(context, continueRecipe!),
                  onToggleFavorite: () =>
                      recipeProvider.toggleFavorite(continueRecipe!.id),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              if (favoritesTop.isNotEmpty) ...[
                Text(
                  DashboardLabels.favoritesHeader,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _RecipeCarousel(
                  recipes: favoritesTop,
                  domainProvider: domainProvider,
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
              ],
              Text(
                DashboardLabels.recentRecipesHeader,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (recentTop.isEmpty)
                Text(
                  DashboardLabels.noRecentRecipesYet,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                _RecipeCarousel(
                  recipes: recentTop,
                  domainProvider: domainProvider,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Recipe/ingredient/cost counts plus a tappable per-domain breakdown —
/// tapping a domain chip jumps to the Recipes tab pre-filtered to it.
class _SummaryCard extends StatelessWidget {
  final int recipeCount;
  final int ingredientCount;
  final double? totalCost;
  final String currencySymbol;
  final List<DomainDef> domainsInUse;
  final Map<String, int> countsByDomainId;

  const _SummaryCard({
    required this.recipeCount,
    required this.ingredientCount,
    required this.totalCost,
    required this.currencySymbol,
    required this.domainsInUse,
    required this.countsByDomainId,
  });

  @override
  Widget build(BuildContext context) {
    final cost = totalCost;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: '$recipeCount',
                    label: recipeCount == 1
                        ? DashboardLabels.recipeStatSingular
                        : DashboardLabels.recipeStatPlural,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    value: '$ingredientCount',
                    label: DashboardLabels.ingredientStat,
                  ),
                ),
                if (cost != null)
                  Expanded(
                    child: _StatTile(
                      value: '$currencySymbol${cost.toStringAsFixed(2)}',
                      label: DashboardLabels.costStat,
                    ),
                  ),
              ],
            ),
            if (domainsInUse.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final domain in domainsInUse)
                    ActionChip(
                      avatar: DomainIconBadge(domain: domain, size: 18),
                      label: Text('${countsByDomainId[domain.id]} '
                          '${domain.name}'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context
                          .read<NavigationProvider>()
                          .goToRecipesFilteredByDomain(domain.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Icon-plus-label menu shortcut — used for "Add Recipe/Formula" and
/// "Quick Ratio Calculator" under the Ratiofy section.
class _MenuIconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal, non-scrollable-height row of [_RecipeMiniCard]s — shared by
/// the Favorites and Recently Added sections.
class _RecipeCarousel extends StatelessWidget {
  final List<Recipe> recipes;
  final DomainProvider domainProvider;

  const _RecipeCarousel({
    required this.recipes,
    required this.domainProvider,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return _RecipeMiniCard(
            recipe: recipe,
            domain: domainProvider.resolve(recipe.domainId),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact card for the Favorites/Recently Added carousels — a photo or
/// domain-icon header (with a small favorite badge when relevant) plus the
/// recipe name and domain.
class _RecipeMiniCard extends StatelessWidget {
  final Recipe recipe;
  final DomainDef domain;
  final VoidCallback onTap;

  const _RecipeMiniCard({
    required this.recipe,
    required this.domain,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = domain.paletteFor(theme.brightness);
    final hasPhoto = recipe.photoPaths.isNotEmpty;

    return SizedBox(
      width: 132,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 80,
                    width: double.infinity,
                    color: palette.container,
                    alignment: Alignment.center,
                    child: hasPhoto
                        ? buildImageFromPath(recipe.photoPaths.first,
                            fit: BoxFit.cover)
                        : Icon(domain.icon,
                            color: palette.onContainer, size: 28),
                  ),
                  if (recipe.isFavorite)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.star,
                          size: 16,
                          color: theme.colorScheme.tertiary,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 3),
                          ]),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      domain.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
