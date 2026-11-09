import 'block_log.dart';

/// Penjaga popup (`onCreateWindow`). Keputusan D6: **semua** window baru
/// ditolak, termasuk `target=_blank`. WebView baru tidak pernah dibuat.
class PopupGuard {
  PopupGuard({required this.log});

  final BlockLog log;

  /// Mengembalikan `false` = jangan buat window baru.
  bool handle({String? targetUrl, String? currentUrl}) {
    final url = targetUrl ?? currentUrl ?? '(tanpa URL)';
    log.add(url: url, reason: 'popup', kind: BlockKind.popup, rule: 'D6');
    return false;
  }
}
