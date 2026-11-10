import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/logger.dart';

class Bookmark {
  const Bookmark({required this.url, required this.title});

  final String url;
  final String title;
}

class BookmarkStore {
  final List<Bookmark> _items = [];

  List<Bookmark> get items => List.unmodifiable(_items);

  bool contains(String url) => _items.any((b) => b.url == url);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageKeys.bookmarks);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      _items
        ..clear()
        ..addAll([
          for (final e in list)
            if (e is Map && e['url'] is String)
              Bookmark(
                url: e['url'] as String,
                title: e['title'] is String ? e['title'] as String : '',
              ),
        ]);
    } catch (error) {
      Log.e('bookmark', 'gagal memuat bookmark, mulai kosong', error);
    }
  }

  /// Menambah bila belum ada, menghapus bila sudah. Mengembalikan true bila
  /// sekarang tersimpan.
  Future<bool> toggle(String url, String title) async {
    final existing = _items.indexWhere((b) => b.url == url);
    if (existing >= 0) {
      _items.removeAt(existing);
    } else {
      _items.insert(0, Bookmark(url: url, title: title));
    }
    await _save();
    return existing < 0;
  }

  Future<void> remove(String url) async {
    _items.removeWhere((b) => b.url == url);
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.bookmarks,
        jsonEncode([
          for (final b in _items) {'url': b.url, 'title': b.title},
        ]),
      );
    } catch (error) {
      Log.e('bookmark', 'gagal menyimpan bookmark', error);
    }
  }
}
