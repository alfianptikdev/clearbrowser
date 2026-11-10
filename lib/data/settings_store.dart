import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/logger.dart';

/// Pengaturan pengguna: toggle global, override per-situs, situs yang
/// ditandai. Perubahan diumumkan lewat [ChangeNotifier]; `BrowserPage`
/// menerapkannya ke guard dan skrip kosmetik.
class SettingsStore extends ChangeNotifier {
  bool _adblockEnabled = true;
  String _homeUrl = kHomeUrl;
  final Map<String, bool> _siteOverrides = {};
  final Set<String> _userSites = {};

  bool get adblockEnabled => _adblockEnabled;

  /// Halaman awal (tab pertama, tab baru, tombol beranda).
  String get homeUrl => _homeUrl;
  Map<String, bool> get siteOverrides => Map.unmodifiable(_siteOverrides);
  Set<String> get userSites => Set.unmodifiable(_userSites);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _adblockEnabled = prefs.getBool(StorageKeys.adblockEnabled) ?? true;
      final home = prefs.getString(StorageKeys.homeUrl);
      if (home != null && home.isNotEmpty) _homeUrl = home;
      final raw = prefs.getString(StorageKeys.siteOverrides);
      if (raw != null) {
        final map = jsonDecode(raw);
        if (map is Map) {
          _siteOverrides
            ..clear()
            ..addAll({
              for (final e in map.entries)
                if (e.key is String && e.value is bool)
                  e.key as String: e.value as bool,
            });
        }
      }
      _userSites
        ..clear()
        ..addAll(prefs.getStringList(StorageKeys.pinnedSites) ?? const []);
    } catch (error) {
      Log.e('settings', 'gagal memuat pengaturan, pakai default', error);
    }
    notifyListeners();
  }

  Future<void> setAdblockEnabled(bool value) async {
    _adblockEnabled = value;
    notifyListeners();
    await _guard((p) => p.setBool(StorageKeys.adblockEnabled, value));
  }

  /// Simpan halaman awal. [url] kosong = kembali ke default.
  Future<void> setHomeUrl(String url) async {
    _homeUrl = url.isEmpty ? kHomeUrl : url;
    notifyListeners();
    await _guard(
      (p) => url.isEmpty
          ? p.remove(StorageKeys.homeUrl)
          : p.setString(StorageKeys.homeUrl, url),
    );
  }

  Future<void> setSiteEnabled(String domain, bool value) async {
    _siteOverrides[domain.toLowerCase()] = value;
    notifyListeners();
    await _guard(
      (p) => p.setString(StorageKeys.siteOverrides, jsonEncode(_siteOverrides)),
    );
  }

  /// Menandai/melepas situs video. Mengembalikan true bila sekarang ditandai.
  Future<bool> toggleUserSite(String site) async {
    final added = _userSites.add(site);
    if (!added) _userSites.remove(site);
    notifyListeners();
    await _guard(
      (p) => p.setStringList(StorageKeys.pinnedSites, _userSites.toList()),
    );
    return added;
  }

  Future<void> _guard(Future<void> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (error) {
      // Fail-open: pengaturan tetap berlaku di sesi ini.
      Log.e('settings', 'gagal menyimpan pengaturan', error);
    }
  }
}
