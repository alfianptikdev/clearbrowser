import 'package:cleanbrowser/adblock/block_log.dart';
import 'package:cleanbrowser/adblock/navigation_guard.dart';
import 'package:cleanbrowser/adblock/rule_engine.dart';
import 'package:cleanbrowser/adblock/site_profiles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late RuleEngine engine;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    engine = RuleEngine();
  });

  test('siteOf: domain terdaftar, TLD bertingkat aman', () {
    expect(RuleEngine.siteOf('a.b.example.com'), 'example.com');
    expect(RuleEngine.siteOf('example.com'), 'example.com');
    expect(RuleEngine.siteOf('x.shop.co.id'), 'shop.co.id');
    expect(RuleEngine.siteOf('yi.charkshiite.qpon'), 'charkshiite.qpon');
  });

  test(
    'learn: situs diblokir untuk subresource dan navigasi, persisten',
    () async {
      final uri = Uri.parse('https://fv.adnet.cyou/x.js');
      expect(engine.evaluate(RequestKind.subresource, uri).blocked, isFalse);

      expect(await engine.learn('fv.adnet.cyou'), isTrue);
      expect(engine.evaluate(RequestKind.subresource, uri).blocked, isTrue);
      expect(
        engine
            .evaluate(
              RequestKind.navigation,
              Uri.parse('https://other.adnet.cyou/'),
            )
            .blocked,
        isTrue,
      );

      final reloaded = RuleEngine();
      await reloaded.loadLearned();
      expect(reloaded.learned, contains('adnet.cyou'));
    },
  );

  test('learn: allowlist pengguna menang, media tetap lolos', () async {
    await engine.addToAllowlist('adnet.cyou');
    expect(await engine.learn('adnet.cyou'), isFalse);

    await engine.learn('cdn.badhost.cyou');
    expect(
      engine
          .evaluate(
            RequestKind.subresource,
            Uri.parse('https://cdn.badhost.cyou/v.m3u8'),
          )
          .blocked,
      isFalse,
    );
  });

  test(
    'shouldLearn: hanya dari halaman terkunci, lintas situs, bukan allowHosts',
    () {
      final guard = NavigationGuard(engine: engine, log: BlockLog())
        ..profiles = SiteProfiles.fromJson(
          '{"sites":{"video.test":{"allowHosts":["alias.test"]}}}',
        );
      const src = 'https://video.test/e/1';
      expect(guard.shouldLearn(src, 'https://ads.example.net/x'), isTrue);
      expect(guard.shouldLearn(src, 'https://cdn.video.test/x'), isFalse);
      expect(guard.shouldLearn(src, 'https://alias.test/x'), isFalse);
      expect(
        guard.shouldLearn('https://x.com/', 'https://ads.example.net/x'),
        isFalse,
      );
      expect(guard.isPinned(src), isTrue);
      expect(guard.isPinned('https://x.com/'), isFalse);
    },
  );

  test(
    'withUserSites: profil bawaan menang, situs ditandai dapat profil default',
    () {
      final base = SiteProfiles.fromJson(
        '{"sites":{"video.test":{"selectors":["#a"]}}}',
      );
      final merged = base.withUserSites(['video.test', 'mine.test']);
      expect(merged.profileFor('video.test')!.selectors, ['#a']);
      expect(merged.profileFor('www.mine.test'), isNotNull);
      expect(base.profileFor('mine.test'), isNull);
    },
  );
}
