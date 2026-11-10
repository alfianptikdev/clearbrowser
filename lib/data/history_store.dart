import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/logger.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.url,
    required this.title,
    required this.at,
  });

  final String url;
  final String title;
  final DateTime at;

  Map<String, Object> toJson() => {
    'url': url,
    'title': title,
    'at': at.millisecondsSinceEpoch,
  };

  static HistoryEntry? fromJson(Object? json) {
    if (json is! Map || json['url'] is! String) return null;
    final at = json['at'];
    return HistoryEntry(
      url: json['url'] as String,
      title: json['title'] is String ? json['title'] as String : '',
      at: DateTime.fromMillisecondsSinceEpoch(at is int ? at : 0),
    );
  }
}

/// Riwayat kunjungan: terbaru di depan, maks [maxEntries], URL berurutan yang
/// sama tidak diduplikasi.
class HistoryStore {
  static const int maxEntries = 500;

  final List<HistoryEntry> _entries = [];

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageKeys.history);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      _entries
        ..clear()
        ..addAll(list.map(HistoryEntry.fromJson).whereType<HistoryEntry>());
    } catch (error) {
      Log.e('history', 'gagal memuat history, mulai kosong', error);
    }
  }

  Future<void> add(String url, String title, {DateTime? at}) async {
    if (url.isEmpty || url == 'about:blank') return;
    if (_entries.isNotEmpty && _entries.first.url == url) return;
    _entries.insert(
      0,
      HistoryEntry(url: url, title: title, at: at ?? DateTime.now()),
    );
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    await _save();
  }

  Future<void> clear() async {
    _entries.clear();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.history,
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (error) {
      Log.e('history', 'gagal menyimpan history', error);
    }
  }
}
