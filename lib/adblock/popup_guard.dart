import 'block_log.dart';
import '../core/logger.dart';

/// Tindakan yang diambil guard terhadap popup.
enum PopupAction {
  /// Tolak window baru: WebView popup dimatikan sebelum tampil.
  block,

  /// Izinkan: popup dibuka sebagai panel overlay di tab saat ini
  /// (relasi `window.opener` dipertahankan, mis. untuk OAuth).
  show,
}

/// Hasil evaluasi popup guard.
class PopupResult {
  const PopupResult(this.action, {this.url});

  final PopupAction action;

  /// URL popup bila [action] == [PopupAction.show].
  final String? url;
}

/// Penjaga popup (`onCreateWindow`). Keputusan D6: **semua** window baru
/// ditolak kecuali domain allowlist (mis. OAuth login Google).
///
/// Catatan Android: untuk `window.open()` dari JS, plugin tidak menyampaikan
/// URL (null — berasal dari `HitTestResult`). Karena itu `BrowserPage` membuat
/// WebView popup tersembunyi (panel netral) untuk membaca URL aslinya, lalu
/// memanggil guard ini. Hasil [PopupAction.block] → WebView popup dimatikan;
/// [PopupAction.show] → panel ditampilkan sebagai popup view.
class PopupGuard {
  PopupGuard({required this.log, Set<String>? popupAllowlist})
    : _popupAllowlist = popupAllowlist ?? const <String>{'accounts.google.com'};

  final BlockLog log;
  final Set<String> _popupAllowlist;

  PopupResult handle({String? targetUrl, String? currentUrl}) {
    final url = targetUrl ?? currentUrl ?? '(tanpa URL)';
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';

    // Domain allowlist → tampilkan popup view (jangan navigasi tab saat ini:
    // halaman pemanggil harus tetap hidup agar alur OAuth selesai).
    if (host.isNotEmpty &&
        _popupAllowlist.any((a) => host == a || host.endsWith('.$a'))) {
      Log.d('popup', 'izinkan (allowlist): $url');
      return PopupResult(PopupAction.show, url: url);
    }

    log.add(url: url, reason: 'popup', kind: BlockKind.popup, rule: 'D6');
    return const PopupResult(PopupAction.block);
  }
}
