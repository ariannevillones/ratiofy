import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/domain.dart';
import '../utils/domains.dart';

/// Manages user-created custom domains (categories), on top of the fixed
/// built-in set in [Domains]. Persisted locally, available app-wide. Also
/// remembers the last domain the user filtered by and the last domain they
/// created a recipe in, so the dashboard and "New Recipe" dialog can
/// restore that context across app restarts.
class DomainProvider extends ChangeNotifier {
  static const _domainsKey = 'domains.custom.v1';
  static const _seqKey = 'domains.sequenceCounter.v1';
  static const _lastFilterKey = 'domains.lastFilterDomainId.v1';
  static const _lastUsedKey = 'domains.lastUsedDomainId.v1';

  final List<CustomDomain> _customDomains = [];
  int _nextSeq = 1;

  /// Domain the dashboard's filter chip row was last set to. Null means
  /// "All".
  String? _lastFilterDomainId;
  String? get lastFilterDomainId => _lastFilterDomainId;

  /// Domain the user picked the last time they created a recipe, used to
  /// pre-select the "New Recipe" dialog's domain dropdown.
  String? _lastUsedDomainId;
  String? get lastUsedDomainId => _lastUsedDomainId;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<CustomDomain> get customDomains => List.unmodifiable(_customDomains);

  /// Every selectable domain — built-ins first, then custom ones — as
  /// [DomainDef]s ready for display/dropdowns.
  List<DomainDef> get allDomains => [
        ...Domains.builtIn,
        ..._customDomains.map((d) => d.toDomainDef()),
      ];

  DomainDef resolve(String domainId) =>
      Domains.resolve(domainId, _customDomains.map((d) => d.toDomainDef()).toList());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final domainsJson = prefs.getString(_domainsKey);
    if (domainsJson != null) {
      try {
        final decoded = jsonDecode(domainsJson) as List<dynamic>;
        _customDomains
          ..clear()
          ..addAll(decoded
              .map((e) => CustomDomain.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // Corrupt data — start fresh rather than crashing the app.
      }
    }

    final seq = prefs.getInt(_seqKey);
    if (seq != null) _nextSeq = seq;

    _lastFilterDomainId = prefs.getString(_lastFilterKey);
    _lastUsedDomainId = prefs.getString(_lastUsedKey);

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_domainsKey,
        jsonEncode(_customDomains.map((d) => d.toJson()).toList()));
    await prefs.setInt(_seqKey, _nextSeq);
  }

  CustomDomain addDomain(
    String name, {
    String? iconKey,
    int? colorValue,
    String? defaultUnit,
    bool costVisible = true,
    String extraFieldLabel = '',
  }) {
    final domain = CustomDomain(
      id: 'domain_${_nextSeq++}_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      iconKey: iconKey ?? Domains.defaultIconKey,
      colorValue: colorValue,
      defaultUnit: defaultUnit ?? Domains.builtIn.first.defaultUnit,
      costVisible: costVisible,
      extraFieldLabel: extraFieldLabel.trim(),
    );
    _customDomains.add(domain);
    notifyListeners();
    _persist();
    return domain;
  }

  void deleteDomain(String domainId) {
    _customDomains.removeWhere((d) => d.id == domainId);
    notifyListeners();
    _persist();
  }

  /// Records the dashboard's current filter selection. Pass null for "All".
  Future<void> setLastFilterDomainId(String? domainId) async {
    _lastFilterDomainId = domainId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (domainId == null) {
      await prefs.remove(_lastFilterKey);
    } else {
      await prefs.setString(_lastFilterKey, domainId);
    }
  }

  /// Records the domain most recently chosen when creating a recipe.
  Future<void> setLastUsedDomainId(String domainId) async {
    _lastUsedDomainId = domainId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsedKey, domainId);
  }

  // ---------------------------------------------------------------------
  // Backup / restore
  // ---------------------------------------------------------------------

  Map<String, dynamic> exportAll() => {
        'customDomains': _customDomains.map((d) => d.toJson()).toList(),
        'nextSeq': _nextSeq,
      };

  Future<void> importAll(Map<String, dynamic> data) async {
    final decoded = (data['customDomains'] as List<dynamic>? ?? [])
        .map((e) => CustomDomain.fromJson(e as Map<String, dynamic>))
        .toList();
    _customDomains
      ..clear()
      ..addAll(decoded);
    _nextSeq = data['nextSeq'] as int? ?? _nextSeq;
    notifyListeners();
    await _persist();
  }
}
