import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../utils/image_display.dart';

/// Horizontal strip of photo thumbnails for a recipe, with an "add photo"
/// tile (camera or gallery) shown while under the max, and a tap-to-expand
/// full view with delete, for each existing photo.
class PhotoSection extends StatelessWidget {
  final Recipe recipe;

  const PhotoSection({super.key, required this.recipe});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<RecipeProvider>();

    try {
      final file = await picker.pickImage(source: source, imageQuality: 82);
      if (file == null) return;
      final added = provider.addPhoto(recipe.id, file.path);
      if (!added) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('You can add up to 3 photos per recipe.')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Couldn\'t access camera/gallery: $e')),
      );
    }
  }

  Future<void> _showAddPhotoSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExpandedPhoto(BuildContext context, String path) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 520,
                  minHeight: 200,
                  minWidth: 200,
                ),
                child: InteractiveViewer(
                  child: buildImageFromPath(path, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  tooltip: 'Delete photo',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmContext) => AlertDialog(
                        title: const Text('Delete photo?'),
                        content: const Text('This can\'t be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(confirmContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton.tonal(
                            onPressed: () =>
                                Navigator.of(confirmContext).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && dialogContext.mounted) {
                      // ignore: use_build_context_synchronously
                      context.read<RecipeProvider>().deletePhoto(recipe.id, path);
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = recipe.photoPaths;
    final canAddMore = photos.length < Recipe.maxPhotos;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Photos',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Text(
                '(${photos.length}/${Recipe.maxPhotos})',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final path in photos) ...[
                  _PhotoThumbnail(
                    path: path,
                    onTap: () => _showExpandedPhoto(context, path),
                  ),
                  const SizedBox(width: 10),
                ],
                if (canAddMore)
                  _AddPhotoTile(onTap: () => _showAddPhotoSheet(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String path;
  final VoidCallback onTap;

  const _PhotoThumbnail({required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 78,
          height: 78,
          child: buildImageFromPath(path, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          color: theme.colorScheme.surface,
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
