import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/logger.dart';

/// Jenis request yang dievaluasi aturan.
///
/// `navigation` = top-level (klik link/redirect), `subresource` = resource
/// halaman (script, gambar, iframe, XHR), `popup` = window baru.
enum RequestKind { navigation, subresource, popup }

/// Hasil keputusan guard. Selalu dikembalikan (bukan `void`) agar bisa
/// dicatat di `BlockLog` dan diuji.
class BlockDecision {
  const BlockDecision({required this.blocked, required this.reason, this.rule});

  const BlockDecision.allow(this.reason) : blocked = false, rule = null;

  const BlockDecision.block(this.reason, {this.rule}) : blocked = true;

  final bool blocked;

  /// Alasan singkat yang stabil untuk log: `media`, `allowlist`, `host-list`,
  /// `top-level`, `url-pattern`, `scheme`, `error`, `default`.
  final String reason;

  /// Entri rule yang menyebabkan keputusan (host atau pola), bila ada.
  final String? rule;

  @override
  String toString() =>
      'BlockDecision(blocked: $blocked, reason: $reason, rule: $rule)';
}

/// Mesin aturan jaringan. Tidak tahu apa pun soal WebView sehingga bisa
/// diuji murni di VM.
///
/// Aturan keras (lihat `AGENTS.md` §2):
/// - media selalu lolos sebelum blocklist;
/// - error apa pun → fail-open.
class RuleEngine {
  RuleEngine({AssetBundle? bundle}) : _bundle = bundle;

  static const String hostsAsset = 'assets/rules/hosts.txt';

  /// Batas pencarian suffix per label (lihat `docs/RULES-FORMAT.md`).
  static const int maxLabelLookups = 4;

  final AssetBundle? _bundle;

  final Set<String> _hosts = <String>{};
  final Set<String> _allowlist = <String>{};
  final Set<String> _topLevelBlocked = <String>{};

  /// Situs iklan yang dipelajari otomatis dari halaman video (persisten).
  final Set<String> _learned = <String>{};
  static const int maxLearned = 1000;
  final List<({String source, RegExp regex})> _urlPatterns = [];

  bool get isLoaded => _hosts.isNotEmpty;

  int get hostCount => _hosts.length;

  Set<String> get allowlist => Set<String>.unmodifiable(_allowlist);

  Set<String> get learned => Set<String>.unmodifiable(_learned);

  Set<String> get topLevelBlocked => Set<String>.unmodifiable(_topLevelBlocked);

  // ---------------------------------------------------------------------------
  // Pemuatan
  // ---------------------------------------------------------------------------

  /// Memuat `assets/rules/hosts.txt`. Gagal → daftar kosong (fail-open).
  Future<void> loadFromAssets() async {
    try {
      final raw = await (_bundle ?? rootBundle).loadString(hostsAsset);
      loadFromString(raw);
    } catch (error) {
      Log.e('rules', 'gagal memuat $hostsAsset, adblock nonaktif', error);
    }
  }

  /// Mengganti daftar host dari teks mentah. Mengembalikan jumlah host valid.
  int loadFromString(String content) {
    final parsed = <String>{};
    for (final line in content.split('\n')) {
      final host = parseLine(line);
      if (host != null) parsed.add(host);
    }
    _hosts
      ..clear()
      ..addAll(parsed);
    Log.d('rules', '${_hosts.length} host dimuat');
    return _hosts.length;
  }

  /// Satu baris `hosts.txt` → host, atau `null` bila komentar/kosong/invalid.
  static String? parseLine(String line) {
    var value = line.trim();
    if (value.isEmpty || value.startsWith('#')) return null;
    // Toleransi format hosts: "0.0.0.0 ads.example.com".
    final parts = value.split(RegExp(r'\s+'));
    if (parts.length > 1) value = parts.last;
    value = normalizeHost(value);
    if (value.isEmpty || !value.contains('.')) return null;
    return value;
  }

  /// Lowercase, buang skema/port/titik akhir.
  static String normalizeHost(String raw) {
    var host = raw.trim().toLowerCase();
    if (host.contains('://')) {
      host = Uri.tryParse(host)?.host ?? '';
    }
    // Host IPv6 dibiarkan (tidak dipakai blocklist, tapi jangan dirusak).
    if (!host.startsWith('[')) {
      final colon = host.indexOf(':');
      if (colon >= 0) host = host.substring(0, colon);
    }
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    return host;
  }

  /// Dipakai M3/M4 saat `sites.json` sudah dibaca.
  void setTopLevelBlocked(Iterable<String> hosts) {
    _topLevelBlocked
      ..clear()
      ..addAll(hosts.map(normalizeHost).where((host) => host.isNotEmpty));
  }

  /// Pola URL tambahan (mis. `globalUrlPatterns` di `sites.json`).
  void setUrlPatterns(Iterable<String> patterns) {
    _urlPatterns.clear();
    for (final source in patterns) {
      try {
        _urlPatterns.add((
          source: source,
          regex: RegExp(source, caseSensitive: false),
        ));
      } catch (error) {
        Log.e('rules', 'pola tidak valid dilewati: $source', error);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Host yang dipelajari
  // ---------------------------------------------------------------------------

  /// Situs (domain terdaftar) dari host: `a.b.example.com` → `example.com`,
  /// `x.shop.co.id` → `shop.co.id`. shortcut: heuristik panjang label, bukan
  /// public-suffix-list penuh.
  static String siteOf(String rawHost) {
    final parts = normalizeHost(rawHost).split('.');
    if (parts.length <= 2) return parts.join('.');
    final multi = parts.last.length == 2 && parts[parts.length - 2].length <= 3;
    return parts.sublist(parts.length - (multi ? 3 : 2)).join('.');
  }

  Future<void> loadLearned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _learned
        ..clear()
        ..addAll(prefs.getStringList(StorageKeys.learnedHosts) ?? const []);
    } catch (error) {
      Log.e('rules', 'gagal memuat host terpelajari, fail-open', error);
    }
  }

  /// Blokir situs [rawHost] mulai sekarang (subresource, popup, navigasi).
  /// Allowlist pengguna tetap menang. Mengembalikan true bila baru dipelajari.
  Future<bool> learn(String rawHost) async {
    final site = siteOf(rawHost);
    if (site.isEmpty || !site.contains('.')) return false;
    if (isAllowlisted(site) || _learned.contains(site)) return false;
    if (_learned.length >= maxLearned) _learned.remove(_learned.first);
    _learned.add(site);
    Log.d('rules', 'belajar: $site (${_learned.length} total)');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(StorageKeys.learnedHosts, _learned.toList());
    } catch (error) {
      Log.e('rules', 'gagal menyimpan host terpelajari', error);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Allowlist pengguna
  // ---------------------------------------------------------------------------

  Future<void> loadAllowlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(StorageKeys.allowlist) ?? const [];
      _allowlist
        ..clear()
        ..addAll(stored.map(normalizeHost).where((host) => host.isNotEmpty));
    } catch (error) {
      Log.e('rules', 'gagal memuat allowlist, fail-open', error);
    }
  }

  Future<void> addToAllowlist(String rawHost) async {
    final host = normalizeHost(rawHost);
    if (host.isEmpty) return;
    _allowlist.add(host);
    await _persistAllowlist();
  }

  Future<void> removeFromAllowlist(String rawHost) async {
    _allowlist.remove(normalizeHost(rawHost));
    await _persistAllowlist();
  }

  Future<void> _persistAllowlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        StorageKeys.allowlist,
        _allowlist.toList()..sort(),
      );
    } catch (error) {
      // Fail-open: allowlist tetap berlaku di sesi ini meski gagal disimpan.
      Log.e('rules', 'gagal menyimpan allowlist', error);
    }
  }

  // ---------------------------------------------------------------------------
  // Pencocokan
  // ---------------------------------------------------------------------------

  bool isBlockedHost(String host) => matchBlockedHost(host) != null;

  /// Host yang cocok dengan blocklist, atau `null`.
  String? matchBlockedHost(String rawHost) {
    final host = normalizeHost(rawHost);
    return _matchDomain(_hosts, host) ?? _matchDomain(_learned, host);
  }

  bool isAllowlisted(String rawHost) =>
      _matchDomain(_allowlist, normalizeHost(rawHost)) != null;

  bool isTopLevelBlocked(String rawHost) {
    final host = normalizeHost(rawHost);
    return _matchDomain(_topLevelBlocked, host) != null ||
        _matchDomain(_learned, host) != null;
  }

  /// Suffix per label, maksimum [maxLabelLookups] iterasi.
  ///
  /// `ads.doubleclick.net` cocok dengan `doubleclick.net`;
  /// `notdoubleclick.net` tidak.
  static String? _matchDomain(Set<String> domains, String host) {
    var current = host;
    for (var i = 0; i < maxLabelLookups; i++) {
      if (current.isEmpty) return null;
      if (domains.contains(current)) return current;
      final dot = current.indexOf('.');
      if (dot < 0) return null;
      current = current.substring(dot + 1);
    }
    return null;
  }

  static bool _hostMatchesCdn(String host, String cdn) =>
      host == cdn || host.endsWith('.$cdn');

  /// FR-16 / aturan keras #1: media dan host CDN video tidak boleh diblokir.
  bool isMediaUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    for (final ext in kMediaExtensions) {
      if (path.endsWith(ext)) return true;
    }
    // Sebagian player menaruh nama file di query (`?file=video.m3u8`).
    final query = uri.query.toLowerCase();
    if (query.isNotEmpty) {
      for (final ext in kMediaExtensions) {
        if (query.contains(ext)) return true;
      }
    }
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    for (final cdn in kMediaCdnHosts) {
      if (_hostMatchesCdn(host, cdn)) return true;
    }
    return false;
  }

  /// Pemeriksaan pola URL tambahan. Dicocokkan ke URL lengkap.
  bool matchesUrlPattern(Uri uri) {
    if (_urlPatterns.isEmpty) return false;
    final url = uri.toString();
    return _urlPatterns.any((pattern) => pattern.regex.hasMatch(url));
  }

  // ---------------------------------------------------------------------------
  // Keputusan
  // ---------------------------------------------------------------------------

  /// Urutan mengikuti `docs/ARCHITECTURE.md` §2.2. Semua exception → allow.
  BlockDecision evaluate(RequestKind kind, Uri uri) {
    try {
      final scheme = uri.scheme.toLowerCase();

      // 1. Resource lokal / non-jaringan.
      if (scheme == 'blob' || scheme == 'data' || scheme == 'about') {
        return const BlockDecision.allow('scheme');
      }

      // 2. Media selalu lolos — jangan pernah ubah urutan ini.
      if (isMediaUrl(uri)) return const BlockDecision.allow('media');

      final host = uri.host.toLowerCase();
      if (host.isEmpty) return const BlockDecision.allow('no-host');

      // 3. Allowlist pengguna menang atas semua daftar.
      if (isAllowlisted(host)) return const BlockDecision.allow('allowlist');

      // 4. Navigasi top-level tidak memakai blocklist besar.
      if (kind == RequestKind.navigation) {
        if (isTopLevelBlocked(host)) {
          return BlockDecision.block(
            'top-level',
            rule: _matchDomain(_topLevelBlocked, host),
          );
        }
        return const BlockDecision.allow('navigation');
      }

      // 5. Pola URL iklan (kosong di M2; diisi M3/M4 dari sites.json).
      if (matchesUrlPattern(uri)) {
        return BlockDecision.block('url-pattern');
      }

      // 6. Blocklist host untuk subresource/popup.
      final rule = matchBlockedHost(host);
      if (rule != null) return BlockDecision.block('host-list', rule: rule);

      return const BlockDecision.allow('default');
    } catch (error) {
      Log.e('rules', 'evaluate gagal, fail-open', error);
      return const BlockDecision.allow('error');
    }
  }
}
