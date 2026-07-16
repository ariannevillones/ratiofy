import 'package:flutter/foundation.dart';

/// Index of the Recipes/Formulas tab within [HomeShell]'s tab list —
/// shared here (rather than on HomeShell itself) so screens like the
/// Dashboard can reference it without importing home_shell.dart back.
const int recipesTabIndex = 1;

/// Lightweight cross-tab navigation signal — lets a widget on one
/// [HomeShell] tab (e.g. a tappable domain stat on the Dashboard) request
/// that another tab (the Recipes list) switch to and pre-filter by a
/// domain, without threading callbacks through the tab hierarchy.
///
/// Both "pending" fields are one-shot: the receiving widget reads the
/// value and immediately calls the matching `consume*` method so the
/// request doesn't re-fire on the next rebuild.
class NavigationProvider extends ChangeNotifier {
  int? _pendingTabIndex;
  String? _pendingDomainFilter;

  int? get pendingTabIndex => _pendingTabIndex;
  String? get pendingDomainFilter => _pendingDomainFilter;

  /// Requests a switch to the Recipes tab, pre-filtered to [domainId].
  void goToRecipesFilteredByDomain(String domainId) {
    _pendingTabIndex = recipesTabIndex;
    _pendingDomainFilter = domainId;
    notifyListeners();
  }

  void consumeTabIndexRequest() {
    _pendingTabIndex = null;
  }

  void consumeDomainFilterRequest() {
    _pendingDomainFilter = null;
  }
}
