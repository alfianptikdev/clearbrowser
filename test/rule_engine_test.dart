import 'package:cleanbrowser/adblock/block_log.dart';
import 'package:cleanbrowser/adblock/navigation_guard.dart';
import 'package:cleanbrowser/adblock/request_guard.dart';
import 'package:cleanbrowser/adblock/rule_engine.dart';
import 'package:cleanbrowser/adblock/site_profiles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hosts = '''
# komentar
doubleclick.net
ads.example.com
EXOCLICK.com
''';

  late RuleEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = RuleEngine()..loadFromString(hosts);
    await engine.loadAllowlist();
  });

  group('pencocokan host', () {
    test('cocok dengan domain induk dan subdomain', () {
      expect(engine.isBlockedHost('doubleclick.net'), isTrue);
      expect(engine.isBlockedHost('ads.doubleclick.net'), isTrue);
      expect(engine.isBlockedHost('a.b.c.doubleclick.net'), isTrue);
    });

    test('tidak cocok dengan domain yang mirip', () {
      expect(engine.isBlockedHost('notdoubleclick.net'), isFalse);
      expect(engine.isBlockedHost('doubleclick.net.evil.com'), isFalse);
      expect(engine.isBlockedHost('example.com'), isFalse);
    });

    test('port, huruf besar, dan titik akhir dinormalisasi', () {
      expect(engine.isBlockedHost('ads.doubleclick.net:8443'), isTrue);
      expect(engine.isBlockedHost('ADS.DoubleClick.NET'), isTrue);
      expect(engine.isBlockedHost('ads.doubleclick.net.'), isTrue);
    });

    test('format hosts "0.0.0.0 host" diterima', () {
      final parsed = RuleEngine()..loadFromString('0.0.0.0 ads.test.com\n');
      expect(parsed.isBlockedHost('cdn.ads.test.com'), isTrue);
    });

    test('komentar dan baris kosong diabaikan', () {
      final parsed = RuleEngine()
        ..loadFromString('# hanya komentar\n\n  \n\t\n');
      expect(parsed.hostCount, 0);
    });

    test('matchBlockedHost mengembalikan entri yang cocok', () {
      expect(engine.matchBlockedHost('ads.doubleclick.net'), 'doubleclick.net');
      expect(engine.matchBlockedHost('example.com'), isNull);
    });
  });

  group('allowlist', () {
    test('allowlist menang atas blocklist, termasuk subdomain', () async {
      await engine.addToAllowlist('views.doubleclick.net');
      expect(engine.isAllowlisted('views.doubleclick.net'), isTrue);

      final decision = engine.evaluate(
        RequestKind.subresource,
        Uri.parse('https://ads.views.doubleclick.net/a.js'),
      );
      expect(decision.blocked, isFalse);
      expect(decision.reason, 'allowlist');
    });

    test('allowlist disimpan dan dimuat ulang', () async {
      await engine.addToAllowlist('ads.example.com');

      final reloaded = RuleEngine()..loadFromString(hosts);
      await reloaded.loadAllowlist();
      expect(reloaded.isAllowlisted('ads.example.com'), isTrue);

      await reloaded.removeFromAllowlist('ads.example.com');
      final again = RuleEngine();
      await again.loadAllowlist();
      expect(again.isAllowlisted('ads.example.com'), isFalse);
    });
  });

  group('media bypass', () {
    test('ekstensi media lolos walau host ada di blocklist', () {
      for (final path in <String>[
        '/video.mp4',
        '/stream.m3u8',
        '/segment.ts',
        '/init.m4s',
        '/sub.vtt',
        '/key.key',
        '/audio.m4a',
      ]) {
        final decision = engine.evaluate(
          RequestKind.subresource,
          Uri.parse('https://ads.doubleclick.net$path'),
        );
        expect(decision.blocked, isFalse, reason: path);
        expect(decision.reason, 'media', reason: path);
      }
    });

    test('ekstensi media di query juga lolos', () {
      final decision = engine.evaluate(
        RequestKind.subresource,
        Uri.parse('https://ads.doubleclick.net/player?file=movie.m3u8&x=1'),
      );
      expect(decision.blocked, isFalse);
      expect(decision.reason, 'media');
    });

    test('host CDN video selalu lolos', () {
      for (final host in <String>[
        'r1---sn.googlevideo.com',
        'customer.cloudflarestream.com',
        'cdn.videy.co',
        'abc.b-cdn.net',
      ]) {
        final decision = engine.evaluate(
          RequestKind.subresource,
          Uri.parse('https://$host/anything'),
        );
        expect(decision.blocked, isFalse, reason: host);
        expect(decision.reason, 'media', reason: host);
      }
    });
  });

  group('evaluate', () {
    test('subresource dari host blocklist diblokir', () {
      final decision = engine.evaluate(
        RequestKind.subresource,
        Uri.parse('https://ads.doubleclick.net/pixel.gif'),
      );
      expect(decision.blocked, isTrue);
      expect(decision.reason, 'host-list');
      expect(decision.rule, 'doubleclick.net');
    });

    test('blocklist besar tidak berlaku untuk navigasi top-level', () {
      final decision = engine.evaluate(
        RequestKind.navigation,
        Uri.parse('https://doubleclick.net/'),
      );
      expect(decision.blocked, isFalse);
      expect(decision.reason, 'navigation');
    });

    test('blockTopLevel berlaku untuk navigasi', () {
      engine.setTopLevelBlocked(<String>['popads.net']);
      final decision = engine.evaluate(
        RequestKind.navigation,
        Uri.parse('https://ads.popads.net/landing'),
      );
      expect(decision.blocked, isTrue);
      expect(decision.reason, 'top-level');
      expect(decision.rule, 'popads.net');
    });

    test('skema lokal diloloskan', () {
      for (final url in <String>[
        'about:blank',
        'blob:https://site.test/abc',
        'data:text/html,<b>x</b>',
      ]) {
        final decision = engine.evaluate(
          RequestKind.subresource,
          Uri.parse(url),
        );
        expect(decision.blocked, isFalse, reason: url);
        expect(decision.reason, 'scheme', reason: url);
      }
    });

    test('pola URL tambahan memblokir subresource', () {
      engine.setUrlPatterns(<String>[r'[/?&]ad_id=']);
      final decision = engine.evaluate(
        RequestKind.subresource,
        Uri.parse('https://example.com/player?ad_id=42'),
      );
      expect(decision.blocked, isTrue);
      expect(decision.reason, 'url-pattern');
    });

    test('pola rusak diabaikan, tidak melempar', () {
      engine.setUrlPatterns(<String>['[', '(', r'ok_pattern']);
      expect(
        engine
            .evaluate(
              RequestKind.subresource,
              Uri.parse('https://example.com/'),
            )
            .blocked,
        isFalse,
      );
    });

    test('fail-open saat daftar kosong/korup', () {
      final empty = RuleEngine()..loadFromString('###\n\nbukan host\n');
      final decision = empty.evaluate(
        RequestKind.subresource,
        Uri.parse('https://ads.doubleclick.net/a.js'),
      );
      expect(decision.blocked, isFalse);
      expect(empty.hostCount, 0);
    });

    test('URL tanpa host tidak melempar', () {
      final decision = engine.evaluate(
        RequestKind.subresource,
        Uri.parse('https://'),
      );
      expect(decision.blocked, isFalse);
    });
  });

  group('NavigationGuard', () {
    late NavigationGuard guard;
    late BlockLog log;

    setUp(() {
      log = BlockLog();
      guard = NavigationGuard(engine: engine, log: log);
    });

    test('skema berbahaya diblokir', () {
      for (final url in <String>[
        'intent://scan/#Intent;scheme=zxing;end',
        'market://details?id=com.example',
        'itms-apps://itunes.apple.com/app/id123',
        'tel:+628123',
        'sms:+628123',
        'file:///etc/passwd',
      ]) {
        final decision = guard.evaluate(url);
        expect(decision.blocked, isTrue, reason: url);
        expect(decision.reason, 'scheme', reason: url);
      }
    });

    test('skema lokal dan non-web diloloskan', () {
      for (final url in <String>[
        'about:blank',
        'blob:https://site.test/abc',
        'data:text/plain,hi',
        'javascript:void(0)',
      ]) {
        expect(guard.evaluate(url).blocked, isFalse, reason: url);
      }
    });

    test('skema app kustom di top-level diblokir', () {
      expect(guard.evaluate('shopeeid://reactpath?x=1').blocked, isTrue);
      expect(
        guard.evaluate('shopeeid://x', isForMainFrame: false).blocked,
        isFalse,
      );
    });

    test('halaman video terkunci: lintas situs diblokir, allowHosts lolos', () {
      guard.profiles = SiteProfiles.fromJson(
        '{"sites":{"video.test":{"allowHosts":["alias.test"]}}}',
      );
      const src = 'https://www.video.test/e/1';
      expect(
        guard.evaluate('https://ads.example.net/x', sourceUrl: src).blocked,
        isTrue,
      );
      expect(
        guard.evaluate('https://cdn.video.test/x', sourceUrl: src).blocked,
        isFalse,
      );
      expect(
        guard.evaluate('https://alias.test/e/1', sourceUrl: src).blocked,
        isFalse,
      );
      // Sumber tanpa profil tidak dikunci.
      expect(
        guard
            .evaluate('https://ads.example.net/x', sourceUrl: 'https://x.com/')
            .blocked,
        isFalse,
      );
    });

    test('navigasi ke host blocklist tetap lolos', () {
      expect(guard.evaluate('https://doubleclick.net/').blocked, isFalse);
    });

    test('iframe tidak diperlakukan sebagai top-level', () {
      expect(
        guard
            .evaluate('https://doubleclick.net/', isForMainFrame: false)
            .blocked,
        isFalse,
      );
    });

    test('record mencatat hanya keputusan blokir', () {
      final blocked = guard.evaluate('intent://x');
      guard.record(blocked, 'intent://x');
      guard.record(
        guard.evaluate('https://example.com/'),
        'https://example.com/',
      );

      expect(log.current, hasLength(1));
      expect(log.current.single.kind, BlockKind.navigation);
      expect(log.current.single.reason, 'scheme');
    });
  });

  group('RequestGuard', () {
    test('main frame tidak pernah diblokir di sini', () {
      final guard = RequestGuard(engine: engine, log: BlockLog());
      final decision = guard.evaluate(
        'https://ads.doubleclick.net/',
        isForMainFrame: true,
      );
      expect(decision.blocked, isFalse);
      expect(decision.reason, 'main-frame');
    });

    test('subresource diblokir dan dicatat', () {
      final log = BlockLog();
      final guard = RequestGuard(engine: engine, log: log);
      final decision = guard.evaluate(
        'https://ads.doubleclick.net/a.js',
        isForMainFrame: false,
      );
      expect(decision.blocked, isTrue);
    });
  });

  group('performa', () {
    test('100.000 lookup di bawah 200 ms', () {
      final samples = List<String>.generate(
        2000,
        (i) => 'sub$i.ads${i % 7}.contoh$i.test',
      );
      final stopwatch = Stopwatch()..start();
      var hits = 0;
      for (var i = 0; i < 100000; i++) {
        if (engine.isBlockedHost(samples[i % samples.length])) hits++;
      }
      stopwatch.stop();
      expect(hits, 0);
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });
  });
}
