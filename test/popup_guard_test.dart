import 'package:flutter_test/flutter_test.dart';

import 'package:cleanbrowser/adblock/block_log.dart';
import 'package:cleanbrowser/adblock/popup_guard.dart';

void main() {
  late BlockLog log;
  late PopupGuard guard;

  setUp(() {
    log = BlockLog();
    guard = PopupGuard(log: log);
  });

  test('domain allowlist → show, tidak masuk log', () {
    final result = guard.handle(
      targetUrl: 'https://accounts.google.com/o/oauth2/auth?client=x',
    );
    expect(result.action, PopupAction.show);
    expect(result.url, contains('accounts.google.com'));
    expect(log.total, 0);
  });

  test('subdomain allowlist ikut diizinkan', () {
    final result = guard.handle(targetUrl: 'https://sub.accounts.google.com/a');
    expect(result.action, PopupAction.show);
    expect(log.total, 0);
  });

  test('domain lain → block dan tercatat di log sebagai popup', () {
    final result = guard.handle(targetUrl: 'https://ads.example.net/pop.php');
    expect(result.action, PopupAction.block);
    expect(log.total, 1);
    final entry = log.current.single;
    expect(entry.kind, BlockKind.popup);
    expect(entry.rule, 'D6');
    expect(entry.host, 'ads.example.net');
  });

  test('URL tidak diketahui (window.open JS) → block, dicatat tanpa URL', () {
    final result = guard.handle(targetUrl: null, currentUrl: null);
    expect(result.action, PopupAction.block);
    expect(log.current.single.url, '(tanpa URL)');
  });

  test('host mirip tapi bukan suffix label → tidak dianggap allowlist', () {
    final result = guard.handle(
      targetUrl: 'https://evil-accounts.google.com.evil.io/x',
    );
    expect(result.action, PopupAction.block);
    expect(log.total, 1);
  });
}
