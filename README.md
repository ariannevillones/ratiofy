# Ratiofy

A Flutter app (Web, iOS, Android) for scaling recipe ingredients up or down
based on a target quantity for one chosen "reference" ingredient.

## Features

- **Bottom navigation** — three tabs: **Recipes** (default landing page),
  **Ingredients** (preset ingredient groups), and **Settings**. Each tab
  keeps its own scroll position/state when you switch away and back.
- **Recipes tab (Dashboard)** — list of recipe cards. Tap the floating
  action button to add a new recipe (just enter a name).
- **Ingredients tab** — create/rename/delete labeled preset groups and the
  ingredients inside them (see "Ingredient presets" below). Tap the
  checklist icon on a group to enter **selection mode**, with a **Select
  all** checkbox and a **Delete Selected** action for fast bulk cleanup.
- **Settings tab** — choose a default currency (18 common currencies); the
  symbol is used for every cost field and result across all recipes.
- **Recipe details** — add up to 30 ingredients per recipe. Each ingredient
  has an auto-generated, permanent **Ref #**, plus editable name, quantity,
  unit, and cost.
- **Select all for calculation** — a checkbox above the ingredient list on
  the recipe screen checks/unchecks every ingredient's calculation
  checkbox at once (shows a dash when only some are checked), instead of
  tapping each one individually.
- **Save icon** — a dedicated save button sits directly in the recipe
  screen's app bar (separate from the ⋮ menu) and explicitly flushes the
  recipe to local storage with a confirmation; note that changes also
  auto-save as you make them.
- **Recipe menu** (⋮, top-right of the recipe screen):
  - **Rename** — edit the recipe's name.
  - **Add/Edit notes** — free-text notes/description, shown as a banner at
    the top of the recipe screen when present.
  - **Duplicate recipe** — copies the recipe, its ingredients, and its
    photos (fresh ref numbers, calculated results reset).
  - **Export / Share as text** — builds a plain-text summary and lets you
    copy it to the clipboard (works on web, iOS, and Android alike).
- **Photos** — attach up to 3 photos per recipe, either captured with the
  camera or picked from the gallery. Thumbnails appear in a strip on the
  recipe screen; tap one to view it expanded (pinch/zoom) with a delete
  option.
- **Ingredient presets** — group ingredients you use often (e.g. "Filipino
  Savory Staples": onions, garlic, salt, soy sauce, vinegar, tomatoes, fish
  sauce) in the **Ingredients tab**. Presets are global and available from
  every recipe. Tapping **Add Ingredient** on a recipe now offers a
  choice: a blank ingredient, or **From preset** — a multi-select sheet
  (with a per-group "select all" too) to drop several preset ingredients
  into the recipe at once. A starter "Filipino Savory Staples" group is
  seeded automatically on first launch so the feature is easy to find
  (only once — deleting it won't bring it back).
- **Empty-by-default ingredient names** — new ingredient cards start with
  a blank name field showing a gray hint (e.g. "e.g. Onions, Garlic, Soy
  sauce") instead of pre-filled placeholder text, so there's nothing to
  select-and-delete before typing. Anywhere a name is *displayed* rather
  than edited (the "Calculate for" dropdown, exported text), a blank name
  falls back to "Ingredient #&lt;ref&gt;" so it still reads sensibly.
- **Primary photo on dashboard** — if a recipe has at least one photo, its
  first photo shows as the thumbnail on its dashboard card instead of the
  generic icon.
- **Unit dropdown** — grouped SI and Imperial units for mass, length, and
  temperature, plus "each" (the default).
- **Calculate for** — pick an ingredient by Ref #, type its new target
  quantity, and tap **Calculate**. Defaults to the **first checked
  ingredient** until you pick a different one manually.
- **Per-ingredient checkbox** — only checked ingredients are scaled
  proportionally; unchecked ones (the default) keep their original quantity
  and cost.
- **Cost is optional** — leave it blank if you don't know it. Ingredients
  without a cost simply don't show a "New est. cost" figure; only "New
  quantity" is calculated and displayed for them.
- **New Quantity / New Est. Cost** — read-only results shown on each
  ingredient card after calculating.
- **Material 3** — the app uses Material 3 components throughout (`Chip`,
  `FilledButton`, `IconButton.outlined`/`filledTonal`, `Card`,
  `DropdownButtonFormField`, etc.) with a seeded color scheme that adapts
  to light and dark mode automatically (follows the system setting).
- **Local persistence** — recipes and settings are saved on-device via
  `shared_preferences`, so your data survives app restarts.

## How the calculation works

1. **Calculate for** defaults to the first ingredient you've checked (in
   list order). You can override it any time via the dropdown — your manual
   pick sticks until you delete that ingredient.
2. Enter the reference ingredient's new target quantity.
3. The app computes `ratio = newQuantity / referenceIngredient.quantity`.
4. For every ingredient whose checkbox is checked, `newQuantity = quantity *
   ratio` and `newCost = cost * ratio`.
5. Unchecked ingredients are left unchanged.

> Tip: if you want the reference ingredient itself to show the exact value
> you typed, check its box too — checking it lets the math apply to it the
> same way as any other ingredient, and the ratio is defined so that its
> result equals exactly what you typed.

## Project structure

```
lib/
  models/
    ingredient.dart       Ingredient data model (+ JSON, displayName)
    recipe.dart            Recipe data model — ingredients, notes, photos,
                            ref counter, effective "Calculate for" logic
    preset.dart             PresetGroup / PresetIngredient data models
  providers/
    recipe_provider.dart    App state (ChangeNotifier), calculation logic,
                             persistence, duplicate/export, photos
    settings_provider.dart  Default currency, persisted
    preset_provider.dart    Global ingredient preset groups, persisted,
                             seeds a starter group on first launch
  screens/
    home_shell.dart             Bottom NavigationBar shell (Recipes/
                                 Ingredients/Settings tabs)
    dashboard_screen.dart       Recipe list + add-recipe dialog (Recipes tab)
    recipe_detail_screen.dart   Calculate-for bar, select-all, photos,
                                 ingredient list, recipe menu (rename/notes/
                                 duplicate/export), standalone Save icon
    settings_screen.dart        Default currency picker (Settings tab)
    presets_screen.dart         Create/edit/delete preset groups &
                                 ingredients, selection mode + bulk delete
                                 (Ingredients tab)
  widgets/
    recipe_card.dart          Dashboard recipe card (shows primary photo)
    ingredient_card.dart      Editable ingredient card (optional cost)
    photo_section.dart        Photo thumbnails, camera/gallery, expand/delete
    preset_picker_sheet.dart  Multi-select sheet to add preset ingredients
  utils/
    units.dart              Grouped SI/Imperial unit definitions
    currencies.dart          Selectable currency list
    image_display.dart       Cross-platform (web/native) image rendering
  main.dart                  App entry point, theme, provider wiring
```

## Getting started

This repo contains the `lib/` source and `pubspec.yaml` only. Flutter's
platform folders (`android/`, `ios/`, `web/`) are generated locally to keep
this bundle small and avoid stale/platform-version-specific boilerplate.

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install)
   (stable channel).
2. Unzip this project and open a terminal in its root folder.
3. Generate the platform folders:
   ```bash
   flutter create . --project-name ratiofy --org com.example
   ```
   This adds `android/`, `ios/`, and `web/` without touching your existing
   `lib/` or `pubspec.yaml`.
4. Fetch dependencies:
   ```bash
   flutter pub get
   ```
5. **Enable camera/gallery access** (required for the Photos feature):

   **iOS** — open `ios/Runner/Info.plist` and add:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Used to take photos of your recipes.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Used to attach photos to your recipes.</string>
   ```

   **Android** — `image_picker` handles most of this automatically, but if
   you target `compileSdk`/`targetSdk` 33+, double-check
   `android/app/build.gradle` has `minSdkVersion 21` or higher (required by
   `image_picker`).

   **Web** — no extra setup; the browser will prompt for camera/file
   access when needed.

6. Run it:
   ```bash
   flutter run -d chrome     # Web
   flutter run -d ios        # iOS simulator (macOS + Xcode required)
   flutter run -d android    # Android emulator/device
   ```

## Notes / assumptions

- An **ingredient name** field was added (not explicitly listed in the
  original spec alongside quantity/unit/cost) since each card needs a human
  -readable label besides its Ref #.
- Ref numbers are assigned sequentially per recipe and are never reused,
  even after deleting an ingredient, so they stay stable as a reference key.
- All data is kept in memory for this version — closing the app clears it.
  Persistence (e.g. via `shared_preferences` or a database) can be added
  later if needed.
- A delete button was added to recipe cards on the dashboard for basic
  recipe management, since the spec didn't say how recipes get removed.
- **Web photo persistence caveat**: on Flutter Web, `image_picker` returns
  a temporary `blob:` URL rather than a real file path. Photos display
  fine during your session, but that URL doesn't survive a full page
  reload, so photos added on web won't persist across refreshes (they're
  fine on iOS/Android/desktop, where a real file path is stored). If you
  need durable web photo storage, the next step would be uploading the
  picked bytes to a backend or object storage rather than keeping a local
  path.
