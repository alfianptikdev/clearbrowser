import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cleanbrowser/adblock/cosmetic_script.dart';
import 'package:cleanbrowser/adblock/site_profiles.dart';

void main() {
  const json = '''
{"sites":{
  "example.com":{"enabled":true,"stealth":true,"selectors":["#ov"],"note":"x"},
  "ads.example.com":{"selectors":["#sub"]},
  "off.test":{"enabled":false}
}}''';

  test('parse valid', () {
    final p = SiteProfiles.fromJson(json).profileFor('example.com')!;
    expect(p.stealth, isTrue);
    expect(p.selectors, ['#ov']);
    expect(p.note, 'x');
  });

  test('field hilang → default', () {
    final p = SiteProfiles.fromJson(json).profileFor('ads.example.com')!;
    expect(p.enabled, isTrue);
    expect(p.stealth, isFalse);
    expect(p.closeSelectors, isEmpty);
  });

  test('JSON rusak / bentuk salah → kosong tanpa melempar', () {
    expect(SiteProfiles.fromJson('{bukan json').all, isEmpty);
    expect(SiteProfiles.fromJson('[1,2]').all, isEmpty);
    expect(SiteProfiles.fromJson('{"sites":{"a.com":5}}').all.length, 1);
  });

  test('subdomain match dan www diabaikan', () {
    final s = SiteProfiles.fromJson(json);
    expect(s.profileFor('www.example.com')?.domain, 'example.com');
    expect(s.profileFor('cdn.example.com')?.domain, 'example.com');
    expect(s.profileFor('notexample.com'), isNull);
  });

  test('yang paling spesifik menang', () {
    final s = SiteProfiles.fromJson(json);
    expect(s.profileFor('x.ads.example.com')?.domain, 'ads.example.com');
  });

  test('builder memuat selector, hanya profil enabled, tanpa global', () {
    final js = CosmeticScript.build(SiteProfiles.fromJson(json));
    expect(js, contains('#ov'));
    expect(js, isNot(contains('off.test')));
    expect(js.trimLeft(), startsWith('(function'));
    expect(js, isNot(contains('window.__')));
    expect(js, isNot(contains('__PROFILES__')));
  });

  test('sites.json asset valid dan berisi situs target', () {
    final s = SiteProfiles.fromJson(
      File('assets/rules/sites.json').readAsStringSync(),
    );
    for (final d in [
      'doodstream.com',
      'videy.co',
      'streamtape.com',
      'filecoster.com',
    ]) {
      expect(s.profileFor(d), isNotNull, reason: d);
      expect(s.profileFor(d)!.note, isNotEmpty, reason: d);
    }
  });
}
