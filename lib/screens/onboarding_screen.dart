import 'package:flutter/material.dart';

import '../utils/domains.dart';
import '../utils/ui_labels.dart';
import '../widgets/domain_icon.dart';
import '../widgets/ratiofy_logo.dart';

/// First-launch walkthrough shown once (gated by
/// [SettingsProvider.hasSeenOnboarding]) before the dashboard, explaining
/// what Ratiofy does and its core concepts to a brand-new user.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Visibility(
                  visible: !isLastPage,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: TextButton(
                    onPressed: widget.onDone,
                    child: const Text(OnboardingLabels.skip),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [
                  _WelcomePage(),
                  _DomainsPage(),
                  _HowItWorksPage(),
                  _ExtraToolsPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? RatiofyLogo.brandBlue
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    isLastPage ? OnboardingLabels.getStarted : OnboardingLabels.next,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageScaffold extends StatelessWidget {
  const _OnboardingPageScaffold({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final Widget illustration;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          illustration,
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _OnboardingPageScaffold(
      illustration: const RatiofyLogo(iconSize: 64, fontSize: 44),
      title: OnboardingLabels.page1Title,
      body: Text(
        OnboardingLabels.page1Body,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _DomainsPage extends StatelessWidget {
  const _DomainsPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _OnboardingPageScaffold(
      illustration: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final domain in Domains.builtIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: DomainIconBadge(domain: domain, size: 56),
            ),
        ],
      ),
      title: OnboardingLabels.page2Title,
      body: Text(
        OnboardingLabels.page2Body,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingPageScaffold(
      illustration: Icon(
        Icons.calculate_outlined,
        size: 64,
        color: RatiofyLogo.brandBlue,
      ),
      title: OnboardingLabels.page3Title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberedStep(number: 1, text: OnboardingLabels.page3Step1),
          SizedBox(height: 12),
          _NumberedStep(number: 2, text: OnboardingLabels.page3Step2),
          SizedBox(height: 12),
          _NumberedStep(number: 3, text: OnboardingLabels.page3Step3),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: RatiofyLogo.brandBlue,
          child: Text(
            '$number',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _ExtraToolsPage extends StatelessWidget {
  const _ExtraToolsPage();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingPageScaffold(
      illustration: Icon(
        Icons.auto_awesome_outlined,
        size: 64,
        color: RatiofyLogo.brandBlue,
      ),
      title: OnboardingLabels.page4Title,
      body: Column(
        children: [
          _FeatureRow(
            icon: Icons.percent,
            title: OnboardingLabels.page4QuickCalcTitle,
            body: OnboardingLabels.page4QuickCalcBody,
          ),
          SizedBox(height: 20),
          _FeatureRow(
            icon: Icons.inventory_2_outlined,
            title: OnboardingLabels.page4PresetsTitle,
            body: OnboardingLabels.page4PresetsBody,
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: RatiofyLogo.brandBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
