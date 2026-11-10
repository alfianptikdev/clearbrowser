import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PageError {
  const PageError({required this.url, required this.description});

  final String url;
  final String description;
}

/// State satu tab. Controller diisi `onWebViewCreated`.
class BrowserTab {
  BrowserTab({required this.id, required this.url}) : lastUsed = DateTime.now();

  final int id;
  String url;
  String title = '';
  double progress = 0;
  bool isLoading = true;
  bool canGoBack = false;
  bool canGoForward = false;
  PageError? error;
  InAppWebViewController? controller;
  DateTime lastUsed;

  /// Judul pendek untuk tab strip.
  String get label {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    return Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
  }
}

/// Daftar tab, tab aktif, dan batas [maxTabs] (tab paling lama tak dipakai
/// dibuang — widget WebView-nya ikut hilang dari stack).
class TabManager {
  TabManager({required this.homeUrl}) {
    open(homeUrl);
  }

  static const int maxTabs = 10;

  String homeUrl;
  final List<BrowserTab> tabs = [];
  int _nextId = 1;
  late BrowserTab _active;

  BrowserTab get active => _active;
  int get activeIndex => tabs.indexOf(_active);

  BrowserTab open(String url) {
    final tab = BrowserTab(id: _nextId++, url: url);
    tabs.add(tab);
    _active = tab;
    while (tabs.length > maxTabs) {
      final victim = tabs
          .where((t) => t != _active)
          .reduce((a, b) => a.lastUsed.isBefore(b.lastUsed) ? a : b);
      tabs.remove(victim);
    }
    return tab;
  }

  void activate(BrowserTab tab) {
    if (!tabs.contains(tab)) return;
    tab.lastUsed = DateTime.now();
    _active = tab;
  }

  /// Menutup tab. Tab terakhir diganti tab beranda baru (selalu ≥ 1 tab).
  void close(BrowserTab tab) {
    final index = tabs.indexOf(tab);
    if (index < 0) return;
    tabs.removeAt(index);
    if (tabs.isEmpty) {
      open(homeUrl);
    } else if (tab == _active) {
      _active = tabs[index.clamp(0, tabs.length - 1)];
      _active.lastUsed = DateTime.now();
    }
  }
}
