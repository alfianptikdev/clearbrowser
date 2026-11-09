import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'block_log.dart';
import 'rule_engine.dart';

/// Penjaga subresource (`shouldInterceptRequest`).
/// Alur: `docs/ARCHITECTURE.md` §2.2.
///
/// Callback berjalan di thread WebView; jangan tambahkan I/O di sini.
class RequestGuard {
  RequestGuard({required this.engine, required this.log});

  final RuleEngine engine;
  final BlockLog log;

  /// `null` = lanjutkan request. Selain itu, response kosong = blokir.
  WebResourceResponse? intercept(WebResourceRequest request) {
    final url = request.url.toString();
    final decision = evaluate(
      url,
      isForMainFrame: request.isForMainFrame == true,
    );
    if (!decision.blocked) return null;
    log.add(
      url: url,
      reason: decision.reason,
      kind: BlockKind.request,
      rule: decision.rule,
    );
    return emptyResponse();
  }

  /// Bagian murni dari guard, dipakai unit test.
  BlockDecision evaluate(String url, {required bool isForMainFrame}) {
    if (isForMainFrame) return const BlockDecision.allow('main-frame');
    final uri = Uri.tryParse(url);
    if (uri == null) return const BlockDecision.allow('unparsable');
    return engine.evaluate(RequestKind.subresource, uri);
  }

  static WebResourceResponse emptyResponse() {
    return WebResourceResponse(
      contentType: 'text/plain',
      contentEncoding: 'utf-8',
      data: Uint8List(0),
    );
  }
}
