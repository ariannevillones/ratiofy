import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../utils/domains.dart';
import '../utils/image_display.dart';
import '../utils/ui_labels.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final DomainDef domain;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.domain,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingredientCount = recipe.ingredients.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _RecipeAvatar(recipe: recipe, domain: domain),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(child: _DomainBadge(domain: domain)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            RecipeCardLabels.ingredientCount(ingredientCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (recipe.notes.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.notes_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: recipe.isFavorite
                    ? RecipeCardLabels.unfavoriteTooltip
                    : RecipeCardLabels.favoriteTooltip,
                icon: Icon(
                  recipe.isFavorite ? Icons.star : Icons.star_border,
                  color: recipe.isFavorite
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: onToggleFavorite,
              ),
              IconButton.outlined(
                tooltip: RecipeCardLabels.deleteTooltip,
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill showing which domain (Food, Chemical, ...) a recipe belongs
/// to, so mixed lists stay scannable.
class _DomainBadge extends StatelessWidget {
  final DomainDef domain;

  const _DomainBadge({required this.domain});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = domain.paletteFor(theme.brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.container,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(domain.icon, size: 11, color: palette.onContainer),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              domain.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.onContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the recipe's first uploaded photo as a thumbnail, or a
/// domain-appropriate icon placeholder when no photo has been added yet.
class _RecipeAvatar extends StatelessWidget {
  final Recipe recipe;
  final DomainDef domain;

  const _RecipeAvatar({required this.recipe, required this.domain});

  @override
  Widget build(BuildContext context) {
    final palette = domain.paletteFor(Theme.of(context).brightness);
    final hasPhoto = recipe.photoPaths.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        color: palette.container,
        alignment: Alignment.center,
        child: hasPhoto
            ? buildImageFromPath(recipe.photoPaths.first, fit: BoxFit.cover)
            : Icon(
                domain.icon,
                color: palette.onContainer,
              ),
      ),
    );
  }
}
