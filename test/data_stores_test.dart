import 'package:cleanbrowser/adblock/rule_engine.dart';
import 'package:cleanbrowser/data/bookmark_store.dart';
import 'package:cleanbrowser/data/history_store.dart';
import 'package:cleanbrowser/data/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'history: terbaru di depan, dedupe berurutan, maks 500, persisten',
    () async {
      final h = HistoryStore();
      await h.add('https://a.test/', 'A');
      await h.add('https://a.test/', 'A lagi');
      await h.add('about:blank', '');
      await h.add('https://b.test/', 'B');
      expect(h.entries.map((e) => e.url), [
        'https://b.test/',
        'https://a.test/',
      ]);

      for (var i = 0; i < 600; i++) {
        await h.add('https://x.test/$i', '$i');
      }
      expect(h.entries.length, HistoryStore.maxEntries);
      expect(h.entries.first.url, 'https://x.test/599');

      final reloaded = HistoryStore();
      await reloaded.load();
      expect(reloaded.entries.length, HistoryStore.maxEntries);
      await reloaded.clear();
      expect(reloaded.entries, isEmpty);
    },
  );

  test('bookmark: toggle tambah/hapus, persisten', () async {
    final b = BookmarkStore();
    expect(await b.toggle('https://a.test/', 'A'), isTrue);
    expect(b.contains('https://a.test/'), isTrue);

    final reloaded = BookmarkStore();
    await reloaded.load();
    expect(reloaded.items.single.title, 'A');
    expect(await reloaded.toggle('https://a.test/', 'A'), isFalse);
    expect(reloaded.items, isEmpty);
  });

  test(
    'settings: toggle global, override situs, situs ditandai persisten',
    () async {
      final s = SettingsStore();
      var notified = 0;
      s.addListener(() => notified++);
      await s.setAdblockEnabled(false);
      await s.setSiteEnabled('Video.Test', false);
      expect(await s.toggleUserSite('mine.test'), isTrue);
      expect(notified, 3);

      final reloaded = SettingsStore();
      await reloaded.load();
      expect(reloaded.adblockEnabled, isFalse);
      expect(reloaded.siteOverrides['video.test'], isFalse);
      expect(reloaded.userSites, {'mine.test'});
    },
  );

  test('engine: enabled=false meloloskan semuanya; unlearn melepas', () async {
    final e = RuleEngine()..loadFromString('ads.example.net\n');
    final uri = Uri.parse('https://ads.example.net/x.js');
    expect(e.evaluate(RequestKind.subresource, uri).blocked, isTrue);
    e.enabled = false;
    expect(e.evaluate(RequestKind.subresource, uri).blocked, isFalse);
    e.enabled = true;

    await e.learn('a.bad.cyou');
    expect(e.learned, contains('bad.cyou'));
    await e.unlearn('bad.cyou');
    expect(e.learned, isEmpty);
  });
}
