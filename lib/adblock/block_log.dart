import 'package:flutter/foundation.dart';

import '../core/constants.dart';

/// Asal keputusan blokir, dipakai untuk pengelompokan di UI.
enum BlockKind { request, navigation, popup }

class BlockLogEntry {
  const BlockLogEntry({
    required this.host,
    required this.url,
    required this.reason,
    required this.kind,
    required this.time,
    this.rule,
  });

  final String host;
  final String url;
  final String reason;
  final BlockKind kind;
  final DateTime time;
  final String? rule;
}

/// Ring buffer 500 entri terakhir + notifier untuk UI.
///
/// `shouldInterceptRequest` tidak boleh melakukan I/O; kelas ini hanya
/// menyentuh memori.
class BlockLog {
  BlockLog({this.capacity = kMaxBlockLogEntries}) : assert(capacity > 0);

  final int capacity;

  final List<BlockLogEntry> _entries = <BlockLogEntry>[];
  final ValueNotifier<List<BlockLogEntry>> entries =
      ValueNotifier<List<BlockLogEntry>>(const <BlockLogEntry>[]);

  int _total = 0;

  /// Jumlah blokir sejak log terakhir dibersihkan (bisa > [capacity]).
  int get total => _total;

  List<BlockLogEntry> get current => List<BlockLogEntry>.unmodifiable(_entries);

  void add({
    required String url,
    required String reason,
    required BlockKind kind,
    String? rule,
    DateTime? time,
  }) {
    final entry = BlockLogEntry(
      host: hostOf(url),
      url: url,
      reason: reason,
      kind: kind,
      rule: rule,
      time: time ?? DateTime.now(),
    );
    _entries.insert(0, entry);
    if (_entries.length > capacity) {
      _entries.removeRange(capacity, _entries.length);
    }
    _total++;
    // Salinan baru agar ValueNotifier pasti memberi tahu listener.
    entries.value = List<BlockLogEntry>.unmodifiable(_entries);
  }

  void clear() {
    _entries.clear();
    _total = 0;
    entries.value = const <BlockLogEntry>[];
  }

  /// Host untuk ditampilkan; fallback ke URL bila tidak bisa diparse.
  static String hostOf(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? url : host.toLowerCase();
  }
}
