import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/logger.dart';

/// Profil kosmetik satu situs. Skema: `docs/RULES-FORMAT.md` §2.
class SiteProfile {
  const SiteProfile({
    required this.domain,
    this.enabled = true,
    this.stealth = false,
    this.selectors = const [],
    this.closeSelectors = const [],
    this.extraUrlPatterns = const [],
    this.allowHosts = const [],
    this.note = '',
  });

  final String domain;
  final bool enabled;
  final bool stealth;
  final List<String> selectors;
  final List<String> closeSelectors;
  final List<String> extraUrlPatterns;
  final List<String> allowHosts;
  final String note;

  SiteProfile copyWith({bool? enabled}) => SiteProfile(
    domain: domain,
    enabled: enabled ?? this.enabled,
    stealth: stealth,
    selectors: selectors,
    closeSelectors: closeSelectors,
    extraUrlPatterns: extraUrlPatterns,
    allowHosts: allowHosts,
    note: note,
  );

  /// Field hilang/salah tipe → default; tidak pernah melempar.
  factory SiteProfile.fromJson(String domain, Object? json) {
    final m = json is Map ? json : const {};
    List<String> strings(String key) {
      final v = m[key];
      return v is List ? v.whereType<String>().toList() : const [];
    }

    return SiteProfile(
      domain: domain.toLowerCase(),
      enabled: m['enabled'] is bool ? m['enabled'] as bool : true,
      stealth: m['stealth'] is bool ? m['stealth'] as bool : false,
      selectors: strings('selectors'),
      closeSelectors: strings('closeSelectors'),
      extraUrlPatterns: strings('extraUrlPatterns'),
      allowHosts: strings('allowHosts'),
      note: m['note'] is String ? m['note'] as String : '',
    );
  }

  Map<String, Object> toJson() => {
    'domain': domain,
    'stealth': stealth,
    'selectors': selectors,
    'closeSelectors': closeSelectors,
  };
}

/// Kumpulan profil dari `assets/rules/sites.json`.
class SiteProfiles {
  SiteProfiles(
    Map<String, SiteProfile> profiles, {
    this.blockTopLevel = const [],
    this.globalUrlPatterns = const [],
  }) : _profiles = Map.unmodifiable(profiles);

  SiteProfiles.empty()
    : _profiles = const {},
      blockTopLevel = const [],
      globalUrlPatterns = const [];

  /// Host yang diblokir juga untuk navigasi top-level.
  final List<String> blockTopLevel;
  final List<String> globalUrlPatterns;

  static const String asset = 'assets/rules/sites.json';

  final Map<String, SiteProfile> _profiles;

  Iterable<SiteProfile> get all => _profiles.values;

  /// Salinan dengan profil default untuk situs yang ditandai pengguna
  /// (profil dari `sites.json` tetap menang).
  SiteProfiles withUserSites(Iterable<String> domains) {
    final merged = {..._profiles};
    for (final d in domains) {
      final key = d.toLowerCase();
      merged.putIfAbsent(key, () => SiteProfile(domain: key));
    }
    return SiteProfiles(
      merged,
      blockTopLevel: blockTopLevel,
      globalUrlPatterns: globalUrlPatterns,
    );
  }

  /// Terapkan toggle per-situs pengguna (`domain` → enabled).
  SiteProfiles withOverrides(Map<String, bool> overrides) {
    return SiteProfiles(
      {
        for (final e in _profiles.entries)
          e.key: overrides.containsKey(e.key)
              ? e.value.copyWith(enabled: overrides[e.key])
              : e.value,
      },
      blockTopLevel: blockTopLevel,
      globalUrlPatterns: globalUrlPatterns,
    );
  }

  /// Ada profil bawaan (`sites.json`) untuk [host]?
  bool hasProfile(String host) => profileFor(host) != null;

  /// JSON rusak → kosong + log (fail-open: tanpa profil, sweep generik jalan).
  factory SiteProfiles.fromJson(String source) {
    try {
      final root = jsonDecode(source);
      final sites = root is Map ? root['sites'] : null;
      if (sites is! Map) return SiteProfiles.empty();
      List<String> strings(String key) {
        final v = root is Map ? root[key] : null;
        return v is List ? v.whereType<String>().toList() : const [];
      }

      return SiteProfiles(
        {
          for (final e in sites.entries)
            if (e.key is String)
              (e.key as String).toLowerCase(): SiteProfile.fromJson(
                e.key as String,
                e.value,
              ),
        },
        blockTopLevel: strings('blockTopLevel'),
        globalUrlPatterns: strings('globalUrlPatterns'),
      );
    } catch (error) {
      Log.e('sites', 'sites.json rusak, profil kosong', error);
      return SiteProfiles.empty();
    }
  }

  static Future<SiteProfiles> load([AssetBundle? bundle]) async {
    try {
      return SiteProfiles.fromJson(
        await (bundle ?? rootBundle).loadString(asset),
      );
    } catch (error) {
      Log.e('sites', 'gagal memuat sites.json', error);
      return SiteProfiles.empty();
    }
  }

  /// Cocokkan domain + subdomain (`www.` diabaikan); yang paling spesifik
  /// (domain terpanjang) menang.
  SiteProfile? profileFor(String host) {
    var h = host.toLowerCase();
    if (h.startsWith('www.')) h = h.substring(4);
    SiteProfile? best;
    for (final p in _profiles.values) {
      if (h == p.domain || h.endsWith('.${p.domain}')) {
        if (best == null || p.domain.length > best.domain.length) best = p;
      }
    }
    return best;
  }
}
