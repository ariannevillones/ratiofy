import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/domain_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/preset_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'utils/app_info.dart';
import 'widgets/ratiofy_logo.dart';

void main() {
  runApp(const RatiofyApp());
}

class RatiofyApp extends StatelessWidget {
  const RatiofyApp({super.key});

  static const _seedColor = Color(0xFF3AC1F2);

  /// Shared Material 3 theme builder for both light and dark brightness.
  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
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
      // Floating snackbars are positioned above the FAB by Scaffold
      // automatically; the default "fixed" behavior instead spans the
      // bottom edge and covers it, blocking taps.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
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
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
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
/// suddenly populates. Also holds the loading screen up for a minimum
/// time so the branding icon actually gets *seen* once it decodes.
///
/// Earlier this gated on the icon's precache future completing instead
/// of a fixed duration — which sounds more correct, but backfires: the
/// precache future completes the instant the icon finishes decoding, and
/// that was used as the *signal to stop showing the loading screen*, so
/// the transition to home happened in the very same frame the icon
/// became ready, before the user could ever see it painted. A minimum
/// duration avoids that inversion — it lets time pass *after* the icon
/// is ready so it's actually visible — while the precache in
/// [didChangeDependencies] still kicks the decode off as early as
/// possible so it reliably finishes within that window.
class _AppStartupGate extends StatefulWidget {
  const _AppStartupGate();

  @override
  State<_AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<_AppStartupGate> {
  static const _minLoadingScreenDuration = Duration(milliseconds: 3000);

  bool _minDurationElapsed = false;
  bool _precacheStarted = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minLoadingScreenDuration, () {
      if (mounted) setState(() => _minDurationElapsed = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precacheStarted) {
      _precacheStarted = true;
      precacheImage(const AssetImage(RatiofyLogo.iconAssetPath), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<RecipeProvider, SettingsProvider, PresetProvider,
        DomainProvider>(
      builder: (context, recipeProvider, settingsProvider, presetProvider,
          domainProvider, _) {
        final providersLoaded = recipeProvider.isLoaded &&
            settingsProvider.isLoaded &&
            presetProvider.isLoaded &&
            domainProvider.isLoaded;
        if (!providersLoaded || !_minDurationElapsed) {
          return const Scaffold(
            body: Center(child: _LoadingScreen()),
          );
        }
        if (!settingsProvider.hasSeenOnboarding) {
          return OnboardingScreen(
            onDone: () => settingsProvider.setHasSeenOnboarding(),
          );
        }
        return const HomeShell();
      },
    );
  }
}

/// Branded loading screen shown while providers load persisted data from
/// disk, so app startup shows the Ratiofy wordmark instead of a blank
/// page with just a spinner.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const RatiofyLogo(iconSize: 44, fontSize: 34),
        const SizedBox(height: 10),
        Text(
          AppInfo.tagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 40),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: RatiofyLogo.brandBlue,
          ),
        ),
      ],
    );
  }
}
