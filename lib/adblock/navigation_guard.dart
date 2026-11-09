import 'block_log.dart';
import 'rule_engine.dart';

/// Penjaga navigasi top-level (`shouldOverrideUrlLoading`).
/// Alur: `docs/ARCHITECTURE.md` §2.1.
class NavigationGuard {
  NavigationGuard({required this.engine, required this.log});

  final RuleEngine engine;
  final BlockLog log;

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

  BlockDecision evaluate(String url, {bool isForMainFrame = true}) {
    final uri = Uri.tryParse(url);
    if (uri == null) return const BlockDecision.allow('unparsable');

    final scheme = uri.scheme.toLowerCase();
    if (blockedSchemes.contains(scheme)) {
      return BlockDecision.block('scheme', rule: scheme);
    }
    if (passthroughSchemes.contains(scheme)) {
      return const BlockDecision.allow('scheme');
    }
    // Skema lain (javascript:, chrome:, dsb.) biarkan WebView menanganinya.
    if (scheme != 'http' && scheme != 'https') {
      return const BlockDecision.allow('other-scheme');
    }
    // Navigasi di dalam iframe bukan top-level; serahkan ke RequestGuard.
    if (!isForMainFrame) return const BlockDecision.allow('iframe');

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
