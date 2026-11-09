import 'package:cleanbrowser/core/constants.dart';
import 'package:cleanbrowser/core/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeInput', () {
    test('domain tanpa skema diberi https', () {
      expect(normalizeInput('example.com'), 'https://example.com');
      expect(normalizeInput('videy.co'), 'https://videy.co');
      expect(
        normalizeInput('doodstream.com/e/abc123'),
        'https://doodstream.com/e/abc123',
      );
    });

    test('URL dengan skema dibiarkan apa adanya', () {
      expect(
        normalizeInput('https://example.com/a?b=1'),
        'https://example.com/a?b=1',
      );
      expect(normalizeInput('http://example.com'), 'http://example.com');
    });

    test('skema non-web dibiarkan agar diblokir guard', () {
      expect(
        normalizeInput('intent://scan/#Intent;scheme=zxing;end'),
        startsWith('intent://'),
      );
      expect(
        normalizeInput('market://details?id=com.example'),
        startsWith('market://'),
      );
    });

    test('bukan domain menjadi pencarian', () {
      expect(
        normalizeInput('cara nonton video'),
        toSearchUrl('cara nonton video'),
      );
      expect(normalizeInput('kucing'), toSearchUrl('kucing'));
    });

    test('localhost dan IP diberi https', () {
      expect(normalizeInput('localhost:8080'), 'https://localhost:8080');
      expect(
        normalizeInput('192.168.1.10:9090/admin'),
        'https://192.168.1.10:9090/admin',
      );
    });

    test('input kosong menuju beranda', () {
      expect(normalizeInput('   '), kHomeUrl);
    });

    test('spasi di tengah memaksa pencarian', () {
      expect(normalizeInput('example .com'), toSearchUrl('example .com'));
    });
  });

  group('hostOf / isSecureUrl', () {
    test('hostOf', () {
      expect(hostOf('https://DoodStream.com/e/1'), 'doodstream.com');
      expect(hostOf('bukan url'), '');
    });

    test('isSecureUrl', () {
      expect(isSecureUrl('https://example.com'), isTrue);
      expect(isSecureUrl('http://example.com'), isFalse);
    });
  });
}
