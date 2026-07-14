import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/domain_provider.dart';
import 'providers/preset_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(const RatiofyApp());
}

class RatiofyApp extends StatelessWidget {
  const RatiofyApp({super.key});

  static const _seedColor = Color(0xFFE1662F); // warm, food-friendly orange

  /// Shared Material 3 theme builder for both light and dark brightness.
  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFFAF7F2)
          : colorScheme.surface,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RecipeProvider()..load()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => PresetProvider()..load()),
        ChangeNotifierProvider(create: (_) => DomainProvider()..load()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Ratiofy',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: const _AppStartupGate(),
        ),
      ),
    );
  }
}

/// Waits for all providers to finish loading persisted data before
/// showing the dashboard, so the UI never flashes empty state then
/// suddenly populates.
class _AppStartupGate extends StatelessWidget {
  const _AppStartupGate();

  @override
  Widget build(BuildContext context) {
    return Consumer4<RecipeProvider, SettingsProvider, PresetProvider,
        DomainProvider>(
      builder: (context, recipeProvider, settingsProvider, presetProvider,
          domainProvider, _) {
        if (!recipeProvider.isLoaded ||
            !settingsProvider.isLoaded ||
            !presetProvider.isLoaded ||
            !domainProvider.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomeShell();
      },
    );
  }
}
