import 'package:cleanbrowser/adblock/block_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('menyimpan entri terbaru di depan', () {
    final log = BlockLog(capacity: 3);
    for (var i = 0; i < 3; i++) {
      log.add(
        url: 'https://ads.test/$i.js',
        reason: 'host-list',
        kind: BlockKind.request,
      );
    }

    expect(log.current, hasLength(3));
    expect(log.current.first.url, 'https://ads.test/2.js');
    expect(log.total, 3);
  });

  test('ring buffer membuang entri tertua', () {
    final log = BlockLog(capacity: 3);
    for (var i = 0; i < 5; i++) {
      log.add(
        url: 'https://ads.test/$i.js',
        reason: 'host-list',
        kind: BlockKind.request,
      );
    }

    expect(log.current, hasLength(3));
    expect(log.current.map((entry) => entry.url), <String>[
      'https://ads.test/4.js',
      'https://ads.test/3.js',
      'https://ads.test/2.js',
    ]);
    expect(log.total, 5);
  });

  test('clear mengosongkan entri dan total', () {
    final log = BlockLog()
      ..add(
        url: 'https://ads.test/a.js',
        reason: 'host-list',
        kind: BlockKind.request,
      );
    log.clear();

    expect(log.current, isEmpty);
    expect(log.total, 0);
    expect(log.entries.value, isEmpty);
  });

  test('host diambil dari URL', () {
    expect(
      BlockLog.hostOf('https://Ads.Example.com:8080/x.mp4'),
      'ads.example.com',
    );
    expect(BlockLog.hostOf('bukan url'), 'bukan url');
  });
}
