import 'dart:io';

import 'package:cleanbrowser/adblock/rule_pack_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final data = switch (key) {
      'assets/rules/hosts.txt' => '# bawaan\nbuiltin.example.com\n',
      'assets/rules/sites.json' =>
        '{"version":1,"updatedAt":"2026-01-01","sites":{}}',
      'assets/rules/version.json' =>
        '{"version":1,"hostsUrl":"http://x/h","sitesUrl":"http://x/s"}',
      _ => throw StateError('asset tidak ada: $key'),
    };
    return ByteData.sublistView(Uint8List.fromList(data.codeUnits));
  }
}

String _hosts([int n = 150]) =>
    '# pack\n${List.generate(n, (i) => 'ad$i.example.net').join('\n')}\n';
const _sites = '{"version":7,"updatedAt":"2026-11-10","sites":{}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  RulePackLoader loader(http.Client client) => RulePackLoader(
    client: client,
    dirProvider: () async => dir,
    bundle: _FakeBundle(),
  );

  setUp(() => dir = Directory.systemTemp.createTempSync('rp_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('load tanpa cache → asset bawaan', () async {
    final pack = await loader(
      MockClient((_) async => http.Response('', 500)),
    ).load();
    expect(pack.fromCache, isFalse);
    expect(pack.hosts, contains('builtin.example.com'));
    expect(pack.versionLabel, '1 · 2026-01-01');
  });

  test('update valid → cache dipakai load berikutnya', () async {
    final client = MockClient(
      (r) async => http.Response(r.url.path == '/h' ? _hosts() : _sites, 200),
    );
    final l = loader(client);
    final result = await l.update();
    expect(result.ok, isTrue);
    expect(result.pack!.versionLabel, '7 · 2026-11-10');

    final pack = await l.load();
    expect(pack.fromCache, isTrue);
    expect(pack.hosts, contains('ad0.example.net'));
    expect(File('${dir.path}/rule_pack/hosts.txt.tmp').existsSync(), isFalse);
  });

  test('hosts korup / terlalu sedikit ditolak, cache lama utuh', () async {
    final l = loader(
      MockClient(
        (r) async => http.Response(r.url.path == '/h' ? _hosts() : _sites, 200),
      ),
    );
    await l.update();

    for (final bad in [_hosts(10), '${_hosts()}bad host line!\n']) {
      final r = await loader(
        MockClient(
          (q) async => http.Response(q.url.path == '/h' ? bad : _sites, 200),
        ),
      ).update();
      expect(r.ok, isFalse);
      expect(r.message, startsWith('Ditolak'));
    }
    expect((await l.load()).hosts, contains('ad0.example.net'));
  });

  test('sites bukan JSON / tanpa version ditolak', () async {
    for (final bad in ['{bukan json', '{"sites":{}}', '[1]']) {
      final r = await loader(
        MockClient(
          (q) async => http.Response(q.url.path == '/h' ? _hosts() : bad, 200),
        ),
      ).update();
      expect(r.ok, isFalse, reason: bad);
    }
    expect(Directory('${dir.path}/rule_pack').existsSync(), isFalse);
  });

  test(
    'offline / timeout / HTTP error → failure dengan alasan, tanpa cache baru',
    () async {
      final offline = await loader(
        MockClient((_) async => throw const SocketException('down')),
      ).update();
      expect(offline.ok, isFalse);
      expect(offline.message, contains('internet'));

      final http500 = await loader(
        MockClient((_) async => http.Response('', 503)),
      ).update();
      expect(http500.message, contains('503'));
      expect(
        (await loader(
          MockClient((_) async => http.Response('', 500)),
        ).load()).fromCache,
        isFalse,
      );
    },
  );

  test('tanpa URL → pesan belum dikonfigurasi', () async {
    final l = RulePackLoader(
      client: MockClient((_) async => http.Response('', 200)),
      dirProvider: () async => dir,
      bundle: _EmptyUrlBundle(),
    );
    expect(await l.canUpdate, isFalse);
    expect((await l.update()).message, contains('belum dikonfigurasi'));
  });
}

class _EmptyUrlBundle extends _FakeBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/rules/version.json') {
      return ByteData.sublistView(
        Uint8List.fromList(
          '{"version":1,"hostsUrl":"","sitesUrl":""}'.codeUnits,
        ),
      );
    }
    return super.load(key);
  }
}
