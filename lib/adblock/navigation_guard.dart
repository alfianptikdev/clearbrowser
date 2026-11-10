import 'block_log.dart';
import 'rule_engine.dart';
import 'site_profiles.dart';

/// Penjaga navigasi top-level (`shouldOverrideUrlLoading`).
/// Alur: `docs/ARCHITECTURE.md` §2.1.
class NavigationGuard {
  NavigationGuard({required this.engine, required this.log});

  final RuleEngine engine;
  final BlockLog log;

  /// Diisi setelah `sites.json` dimuat. Host yang punya profil = halaman
  /// video yang "dikunci": navigasi top-level lintas situs diblokir.
  SiteProfiles? profiles;

  /// Skema yang tidak boleh membuka aplikasi lain dari dalam browser.
  static const Set<String> blockedSchemes = <String>{
    'intent',
    'market',
    'itms-apps',
    'tel',
    'sms',
    'file',
  };

  /// Skema yang aman diteruskan ke WebView.
  static const Set<String> passthroughSchemes = <String>{
    'about',
    'blob',
    'data',
  };

  /// Profil sumber bila navigasi ke [uri] meninggalkan halaman video yang
  /// terkunci (lintas situs dan bukan `allowHosts`), selain itu `null`.
  SiteProfile? _pinnedViolation(String? sourceUrl, Uri uri) {
    final srcHost = sourceUrl == null ? null : Uri.tryParse(sourceUrl)?.host;
    if (srcHost == null || srcHost.isEmpty) return null;
    final profile = profiles?.profileFor(srcHost);
    if (profile == null || !profile.enabled) return null;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return null;
    final allowed = profile.allowHosts.any(
      (a) => host == a || host.endsWith('.$a'),
    );
    if (allowed || RuleEngine.siteOf(host) == RuleEngine.siteOf(srcHost)) {
      return null;
    }
    return profile;
  }

  /// Halaman [sourceUrl] punya profil (terkunci).
  bool isPinned(String sourceUrl) {
    final host = Uri.tryParse(sourceUrl)?.host ?? '';
    final profile = host.isEmpty ? null : profiles?.profileFor(host);
    return profile != null && profile.enabled;
  }

  /// Target ini layak dipelajari sebagai host iklan: dibuka dari halaman
  /// video terkunci, lintas situs, bukan `allowHosts`.
  bool shouldLearn(String sourceUrl, String targetUrl) {
    final uri = Uri.tryParse(targetUrl);
    return uri != null && _pinnedViolation(sourceUrl, uri) != null;
  }

  BlockDecision evaluate(
    String url, {
    bool isForMainFrame = true,
    String? sourceUrl,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null) return const BlockDecision.allow('unparsable');

    final scheme = uri.scheme.toLowerCase();
    if (blockedSchemes.contains(scheme)) {
      return BlockDecision.block('scheme', rule: scheme);
    }
    if (passthroughSchemes.contains(scheme)) {
      return const BlockDecision.allow('scheme');
    }
    // Skema app kustom (shopeeid:, dll.) di top-level = iklan yang mencoba
    // membuka aplikasi lain. javascript: tetap dilepas ke WebView.
    if (scheme != 'http' && scheme != 'https') {
      if (isForMainFrame && scheme != 'javascript') {
        return BlockDecision.block('scheme', rule: scheme);
      }
      return const BlockDecision.allow('other-scheme');
    }
    // Navigasi di dalam iframe bukan top-level; serahkan ke RequestGuard.
    if (!isForMainFrame) return const BlockDecision.allow('iframe');

    // Halaman video terkunci: tab utama tidak boleh dibawa ke situs lain
    // (redirect iklan). Pemuatan lewat address bar tidak melewati guard ini.
    final locked = _pinnedViolation(sourceUrl, uri);
    if (locked != null) {
      return BlockDecision.block('pinned', rule: locked.domain);
    }

    return engine.evaluate(RequestKind.navigation, uri);
  }

  /// Catat bila diblokir. Mengembalikan keputusan yang sama agar pemanggil
  /// bisa langsung memetakannya ke `NavigationActionPolicy`.
  BlockDecision record(BlockDecision decision, String url) {
    if (decision.blocked) {
      log.add(
        url: url,
        reason: decision.reason,
        kind: BlockKind.navigation,
        rule: decision.rule,
      );
    }
    return decision;
  }
}
