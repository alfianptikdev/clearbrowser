import 'package:cleanbrowser/browser/tab_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mulai dengan satu tab beranda aktif', () {
    final m = TabManager(homeUrl: 'https://home.test/');
    expect(m.tabs.length, 1);
    expect(m.active.url, 'https://home.test/');
  });

  test('open mengaktifkan tab baru; activate pindah tab', () {
    final m = TabManager(homeUrl: 'https://home.test/');
    final first = m.active;
    final second = m.open('https://b.test/');
    expect(m.active, second);
    expect(m.activeIndex, 1);
    m.activate(first);
    expect(m.active, first);
  });

  test('close tab aktif memilih tetangga; tab terakhir diganti beranda', () {
    final m = TabManager(homeUrl: 'https://home.test/');
    final a = m.active;
    final b = m.open('https://b.test/');
    m.close(b);
    expect(m.active, a);
    m.close(a);
    expect(m.tabs.length, 1);
    expect(m.active.url, 'https://home.test/');
    expect(m.active.id, isNot(a.id));
  });

  test('batas 10 tab: yang paling lama tak dipakai dibuang, aktif aman', () {
    final m = TabManager(homeUrl: 'https://home.test/');
    final oldest = m.active;
    oldest.lastUsed = DateTime(2000);
    for (var i = 0; i < 10; i++) {
      m.open('https://t$i.test/');
    }
    expect(m.tabs.length, TabManager.maxTabs);
    expect(m.tabs, isNot(contains(oldest)));
    expect(m.tabs, contains(m.active));
  });

  test('label: judul bila ada, selain itu host tanpa www', () {
    final t = BrowserTab(id: 1, url: 'https://www.video.test/e/1');
    expect(t.label, 'video.test');
    t.title = 'Judul';
    expect(t.label, 'Judul');
  });
}
