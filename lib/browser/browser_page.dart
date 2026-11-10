import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../adblock/block_log.dart';
import '../adblock/cosmetic_script.dart';
import '../adblock/navigation_guard.dart';
import '../adblock/popup_guard.dart';
import '../adblock/request_guard.dart';
import '../adblock/rule_engine.dart';
import '../adblock/rule_pack_loader.dart';
import '../adblock/site_profiles.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../core/url_utils.dart';
import '../data/bookmark_store.dart';
import '../data/history_store.dart';
import '../data/settings_store.dart';
import '../ui/block_log_sheet.dart';
import '../ui/cosmetic_test_page.dart';
import '../ui/settings_page.dart';
import 'address_bar.dart';
import 'tab_manager.dart';
import 'tab_view_stack.dart';
import 'webview_setup.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

/// Sesi satu popup (D6 + pengecualian allowlist OAuth).
///
/// WebView popup dibuat dengan `windowId` dari `onCreateWindow` agar transport
/// `WebViewTransport` dipenuhi dan halaman pemanggil tetap punya
/// `window.opener`. [decided] == false berarti URL asli belum diketahui
/// (Android tidak menyampaikan URL `window.open()` JS), sehingga panel masih
/// menampilkan scrim netral sampai `onLoadStart` membaca URL pertama.
class _PopupSession {
  _PopupSession({required this.windowId, required this.decided, this.url});

  final int windowId;
  bool decided;
  String? url;
}

class _BrowserPageState extends State<BrowserPage> {
  final TextEditingController _urlController = TextEditingController(
    text: kHomeUrl,
  );
  final FocusNode _focusNode = FocusNode();

  // Adblock layer (M2). Semua keputusan lewat guard; page hanya memetakan
  // hasilnya ke callback WebView.
  final RuleEngine _ruleEngine = RuleEngine();
  final BlockLog _blockLog = BlockLog();
  late final RequestGuard _requestGuard = RequestGuard(
    engine: _ruleEngine,
    log: _blockLog,
  );
  late final NavigationGuard _navigationGuard = NavigationGuard(
    engine: _ruleEngine,
    log: _blockLog,
  );
  late final PopupGuard _popupGuard = PopupGuard(log: _blockLog);

  bool _isFullscreen = false;
  _PopupSession? _popup;

  // Tab (M4): state per tab di BrowserTab; getter di bawah = tab aktif.
  final TabManager _tabs = TabManager(homeUrl: kHomeUrl);
  BrowserTab get _tab => _tabs.active;
  String get _currentUrl => _tab.url;

  // Data & pengaturan (M4).
  final SettingsStore _settings = SettingsStore();
  final HistoryStore _history = HistoryStore();
  final BookmarkStore _bookmarks = BookmarkStore();
  final RulePackLoader _loader = RulePackLoader();
  String _packLabel = '-';

  /// Skrip kosmetik (M3). WebView baru dibuat setelah ini siap karena
  /// `initialUserScripts` hanya dibaca saat pembuatan.
  String? _cosmeticJs;
  SiteProfiles _baseProfiles = SiteProfiles.empty();

  @override
  void initState() {
    super.initState();
    _initAdblock();
  }

  /// Dimuat setelah frame pertama agar startup tidak menunggu I/O.
  /// Gagal memuat = adblock kosong, bukan crash (fail-open).
  Future<void> _initAdblock() async {
    await _ruleEngine.loadAllowlist();
    await _ruleEngine.loadLearned();
    await _settings.load();
    _applyHomeUrl();
    await _history.load();
    await _bookmarks.load();
    _applyPack(await _loader.load());
    _settings.addListener(_onSettingsChanged);
  }

  /// Pakai halaman awal dari pengaturan. Tab pertama hanya diganti bila
  /// WebView-nya belum dibuat (masih di URL beranda lama).
  void _applyHomeUrl() {
    final home = _settings.homeUrl;
    final first = _tabs.tabs.first;
    if (_tabs.tabs.length == 1 &&
        first.controller == null &&
        first.url == _tabs.homeUrl) {
      first.url = home;
      if (mounted) _urlController.text = home;
    }
    _tabs.homeUrl = home;
  }

  /// Terapkan rule pack (cache/asset/hasil update) ke engine dan profil.
  void _applyPack(RulePack pack) {
    _ruleEngine.loadFromString(pack.hosts);
    _baseProfiles = SiteProfiles.fromJson(pack.sites);
    _ruleEngine.setTopLevelBlocked(_baseProfiles.blockTopLevel);
    _ruleEngine.setUrlPatterns(_baseProfiles.globalUrlPatterns);
    _packLabel = pack.versionLabel;
    _applyProfiles();
  }

  Future<UpdateResult> _updateRulePack() async {
    final result = await _loader.update();
    final pack = result.pack;
    if (result.ok && pack != null) {
      _applyPack(pack);
      await _refreshScripts();
    }
    return result;
  }

  UserScript _cosmeticUserScript(String js) => UserScript(
    source: js,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: false,
  );

  /// Gabungkan profil `sites.json` + override + situs yang ditandai, lalu
  /// bangun ulang skrip kosmetik dan kunci navigasi. Toggle global off →
  /// semua guard dan skrip nonaktif.
  void _applyProfiles() {
    final on = _settings.adblockEnabled;
    _ruleEngine.enabled = on;
    _popupGuard.enabled = on;
    final merged = on
        ? _baseProfiles
              .withOverrides(_settings.siteOverrides)
              .withUserSites(_settings.userSites)
        : SiteProfiles.empty();
    _navigationGuard.profiles = merged;
    final js = CosmeticScript.build(merged);
    if (mounted) setState(() => _cosmeticJs = js);
  }

  /// UserScript hanya berlaku di muatan berikutnya → ganti skrip di semua tab,
  /// lalu muat ulang tab aktif.
  Future<void> _refreshScripts() async {
    final js = _cosmeticJs;
    if (js == null) return;
    for (final tab in _tabs.tabs) {
      await tab.controller?.removeAllUserScripts();
      await tab.controller?.addUserScript(userScript: _cosmeticUserScript(js));
    }
    await _tab.controller?.reload();
  }

  void _onSettingsChanged() {
    _applyProfiles();
    unawaited(_refreshScripts());
  }

  Future<void> _togglePin() async {
    final host = hostOf(_currentUrl);
    if (host.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_baseProfiles.hasProfile(host)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Situs video bawaan, tidak bisa dilepas')),
      );
      return;
    }
    final site = RuleEngine.siteOf(host);
    final added = await _settings.toggleUserSite(site);
    messenger.showSnackBar(
      SnackBar(
        content: Text(added ? '$site ditandai situs video' : '$site dilepas'),
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await _bookmarks.toggle(_tab.url, _tab.title);
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(
        content: Text(added ? 'Bookmark ditambahkan' : 'Bookmark dihapus'),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          settings: _settings,
          engine: _ruleEngine,
          log: _blockLog,
          loader: _loader,
          history: _history,
          bookmarks: _bookmarks,
          baseProfiles: () => _baseProfiles,
          versionLabel: () => _packLabel,
          onUpdate: _updateRulePack,
          onOpenUrl: _loadUrl,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _onMenu(String value) {
    switch (value) {
      case 'bookmark':
        _toggleBookmark();
      case 'blocklog':
        _openBlockLog();
      case 'settings':
        _openSettings();
    }
  }

  /// Host iklan dipelajari hanya bila dibuka dari halaman video terkunci.
  void _learn(BrowserTab tab, String url) {
    if (!_navigationGuard.shouldLearn(tab.url, url)) return;
    final host = hostOf(url);
    if (host.isNotEmpty) unawaited(_ruleEngine.learn(host));
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _urlController.dispose();
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigasi
  // ---------------------------------------------------------------------------

  Future<void> _submit(String raw) async {
    _focusNode.unfocus();
    if (kDebugMode && raw.trim() == 'cb:test') {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CosmeticTestPage()));
      return;
    }
    final url = normalizeInput(raw);
    Log.d('nav', 'submit "$raw" -> $url');
    await _loadUrl(url);
  }

  /// Muat [url] di tab aktif (atau [tab]).
  Future<void> _loadUrl(String url, {BrowserTab? tab}) async {
    final target = tab ?? _tab;
    Log.d('nav', 'loadUrl $url');
    if (target == _tab) _urlController.text = url;
    if (mounted) {
      setState(() {
        target.error = null;
        target.isLoading = true;
        target.progress = 0;
        target.url = url;
      });
    }
    try {
      await target.controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    } catch (error) {
      Log.e('nav', 'loadUrl gagal: $url', error);
    }
  }

  void _setUrl(BrowserTab tab, String url) {
    if (url.isEmpty || url == 'about:blank') return;
    if (tab == _tab && !_focusNode.hasFocus && _urlController.text != url) {
      _urlController.text = url;
    }
    if (url == tab.url) return;
    setState(() => tab.url = url);
  }

  Future<void> _syncNavState(BrowserTab tab) async {
    final webView = tab.controller;
    if (webView == null) return;
    final canGoBack = await webView.canGoBack();
    final canGoForward = await webView.canGoForward();
    if (!mounted) return;
    if (canGoBack == tab.canGoBack && canGoForward == tab.canGoForward) return;
    setState(() {
      tab.canGoBack = canGoBack;
      tab.canGoForward = canGoForward;
    });
  }

  Future<void> _handleBack() async {
    if (_isFullscreen) {
      setState(() => _isFullscreen = false);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }
    final webView = _tab.controller;
    if (webView != null && await webView.canGoBack()) {
      await webView.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Tab
  // ---------------------------------------------------------------------------

  void _selectTab(BrowserTab tab) {
    setState(() => _tabs.activate(tab));
    _urlController.text = tab.url;
  }

  void _closeTab(BrowserTab tab) {
    setState(() => _tabs.close(tab));
    _urlController.text = _tab.url;
  }

  void _newTab() {
    setState(() => _tabs.open(_settings.homeUrl));
    _urlController.text = _settings.homeUrl;
  }

  /// Buka [url] di tab baru. [background] true = tab aktif tetap, halaman
  /// awal tidak tersentuh.
  void _openInNewTab(String url, {bool background = false}) {
    final previous = _tab;
    setState(() {
      _tabs.open(url);
      if (background) _tabs.activate(previous);
    });
    _urlController.text = _tab.url;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            background ? 'Dibuka di tab latar' : 'Dibuka di tab baru',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Link disalin'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  /// Tekan-lama pada link/gambar-berlink: sheet aksi (salin, tab baru, tab latar).
  Future<void> _onLongPress(
    InAppWebViewController controller,
    InAppWebViewHitTestResult hit,
  ) async {
    final type = hit.type;
    if (type != InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE &&
        type != InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE) {
      return;
    }
    final url = hit.extra?.trim() ?? '';
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (url.isEmpty || (scheme != 'http' && scheme != 'https')) return;
    if (!mounted) return;

    final host = hostOf(url);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ),
            ListTile(
              key: const Key('link-open-new-tab'),
              leading: const Icon(Icons.open_in_new),
              title: const Text('Buka di tab baru'),
              subtitle: host.isNotEmpty ? Text(host) : null,
              onTap: () {
                Navigator.pop(sheetContext);
                _openInNewTab(url);
              },
            ),
            ListTile(
              key: const Key('link-open-background'),
              leading: const Icon(Icons.tab_unselected),
              title: const Text('Buka di tab latar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openInNewTab(url, background: true);
              },
            ),
            ListTile(
              key: const Key('link-copy'),
              leading: const Icon(Icons.copy),
              title: const Text('Salin link'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyLink(url);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBlockLog() async {
    await showBlockLogSheet(context, log: _blockLog, engine: _ruleEngine);
  }

  // ---------------------------------------------------------------------------
  // Popup (D6 + allowlist OAuth)
  // ---------------------------------------------------------------------------

  /// Buka panel popup dengan transport `windowId`.
  ///
  /// [decided] false → tampilkan scrim netral dulu; keputusan diambil di
  /// [_onPopupLoadStart] setelah URL asli terbaca. Ada jaga waktu: popup yang
  /// tidak pernah memberi URL nyata dalam 10 detik dibuang + dicatat ke log.
  void _openPopup({required int windowId, required bool decided, String? url}) {
    _closePopup(silent: true);
    final session = _PopupSession(
      windowId: windowId,
      decided: decided,
      url: url,
    );
    setState(() => _popup = session);

    if (decided) return;
    Future.delayed(const Duration(seconds: 10), () {
      final current = _popup;
      if (!mounted || current == null || !identical(current, session)) return;
      if (current.decided || current.url != null) return;
      // Catat sebagai popup blokir tanpa URL (guard yang mencatat).
      _popupGuard.handle(targetUrl: null, currentUrl: null);
      Log.d('popup', 'buang: tidak ada URL asli dalam 10 detik');
      setState(() => _popup = null);
    });
  }

  void _closePopup({bool silent = false}) {
    if (_popup == null) return;
    if (!silent) Log.d('popup', 'tutup popup view');
    _popup = null;
    if (mounted) setState(() {});
  }

  /// Keputusan popup diambil di sini: URL asli baru terlihat setelah WebView
  /// popup menelan transport. Hanya URL pertama yang dievaluasi — setelah
  /// diizinkan, navigasi lanjutan (mis. redirect OAuth) cukup dijaga
  /// navigation/request guard.
  void _onPopupLoadStart(InAppWebViewController controller, WebUri? url) {
    final session = _popup;
    if (session == null) return;
    final target = url?.toString() ?? '';
    if (target.isEmpty || target == 'about:blank') return;
    session.url = target;

    if (session.decided) return; // sudah lolos guard, jangan nilai ulang
    final result = _popupGuard.handle(
      targetUrl: target,
      currentUrl: _currentUrl,
    );
    Log.d('popup', 'URL asli $target → ${result.action}');
    if (result.action == PopupAction.block) {
      _learn(_tab, target);
      // Matikan sebelum iklan sempat tampil (panel pernah tampil sebentar
      // sebagai scrim netral, bukan konten iklan).
      _closePopup();
      return;
    }
    setState(() => session.decided = true);
  }

  /// Halaman pemanggil menutup popup-nya sendiri (`window.close()`),
  /// mis. setelah alur OAuth selesai.
  void _onPopupCloseWindow(InAppWebViewController controller) {
    Log.d('popup', 'halaman memanggil window.close()');
    _closePopup();
  }

  /// Panel popup: bar (host + tombol tutup) di atas WebView popup.
  ///
  /// Selama keputusan belum turun, area WebView ditutup scrim opak agar
  /// konten iklan tidak sempat terlihat sebelum dibuang.
  Widget _buildPopupView() {
    final session = _popup!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final host = session.url != null ? hostOf(session.url!) : '';

    return Positioned.fill(
      child: Material(
        color: colors.surface,
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      host.isNotEmpty ? host : 'Popup',
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _closePopup,
                    icon: const Icon(Icons.close),
                    tooltip: 'Tutup popup',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    // windowId memenuhi transport WebViewTransport dari
                    // onCreateWindow; tanpa ini window.open() selalu gagal.
                    windowId: session.windowId,
                    initialSettings: buildWebViewSettings(),
                    onLoadStart: _onPopupLoadStart,
                    onCloseWindow: _onPopupCloseWindow,
                    shouldOverrideUrlLoading: (controller, action) async {
                      final url = action.request.url?.toString() ?? '';
                      final decision = _navigationGuard.evaluate(
                        url,
                        isForMainFrame: action.isForMainFrame,
                      );
                      _navigationGuard.record(decision, url);
                      if (decision.blocked) {
                        Log.d(
                          'popup',
                          'diblokir nav: $url (${decision.reason})',
                        );
                      }
                      return decision.blocked
                          ? NavigationActionPolicy.CANCEL
                          : NavigationActionPolicy.ALLOW;
                    },
                    shouldInterceptRequest: (controller, request) async =>
                        _requestGuard.intercept(request),
                    onCreateWindow: (controller, action) async {
                      // Window baru dari dalam popup: tetap D6, tolak + catat.
                      final nested = action.request.url?.toString();
                      final result = _popupGuard.handle(
                        targetUrl: nested,
                        currentUrl: session.url,
                      );
                      Log.d(
                        'popup',
                        'window dari popup → ${result.action}: $nested',
                      );
                      return false;
                    },
                    onConsoleMessage: (controller, message) {
                      Log.d(
                        'popup-console',
                        '${message.message} [${message.messageLevel}]',
                      );
                    },
                  ),
                  if (!session.decided)
                    ColoredBox(
                      color: colors.surface,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Callback WebView
  // ---------------------------------------------------------------------------

  void _onLoadStart(BrowserTab tab, InAppWebViewController c, WebUri? url) {
    if (!mounted) return;
    setState(() {
      tab.isLoading = true;
      tab.progress = 0;
      tab.error = null;
    });
  }

  void _onProgressChanged(BrowserTab tab, InAppWebViewController c, int p) {
    if (!mounted) return;
    setState(() => tab.progress = (p / 100).clamp(0.0, 1.0));
  }

  Future<void> _onLoadStop(
    BrowserTab tab,
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (!mounted) return;
    setState(() {
      tab.isLoading = false;
      tab.progress = 1;
    });
    final current = await controller.getUrl();
    if (!mounted) return;
    if (current != null) _setUrl(tab, current.toString());
    final title = await controller.getTitle() ?? '';
    if (!mounted) return;
    setState(() => tab.title = title);
    unawaited(_history.add(tab.url, title));
    await _syncNavState(tab);
  }

  void _onUpdateVisitedHistory(
    BrowserTab tab,
    InAppWebViewController c,
    WebUri? url,
    bool? isReload,
  ) {
    if (url != null) _setUrl(tab, url.toString());
    _syncNavState(tab);
  }

  void _onReceivedError(
    BrowserTab tab,
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    // Error subresource (iklan gagal dimuat, dsb.) tidak boleh menutupi halaman.
    if (request.isForMainFrame != true) return;
    // STOP ditekan pengguna: jangan tampilkan halaman error.
    if (error.type == WebResourceErrorType.CANCELLED) return;
    if (!mounted) return;
    setState(() {
      tab.isLoading = false;
      tab.progress = 0;
      tab.error = PageError(
        url: request.url.toString(),
        description: error.description,
      );
    });
  }

  void _onEnterFullscreen(InAppWebViewController controller) {
    if (!mounted) return;
    setState(() => _isFullscreen = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onExitFullscreen(InAppWebViewController controller) {
    if (!mounted) return;
    setState(() => _isFullscreen = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            if (!_isFullscreen) ...[
              AddressBar(
                controller: _urlController,
                focusNode: _focusNode,
                onSubmitted: _submit,
                onBack: () => _tab.controller?.goBack(),
                onForward: () => _tab.controller?.goForward(),
                onReload: () => _tab.controller?.reload(),
                onStop: () => _tab.controller?.stopLoading(),
                onMenuSelected: _onMenu,
                isBookmarked: _bookmarks.contains(_tab.url),
                onTogglePin: _togglePin,
                isPinned: _navigationGuard.isPinned(_currentUrl),
                canGoBack: _tab.canGoBack,
                canGoForward: _tab.canGoForward,
                isLoading: _tab.isLoading,
                isSecure: isSecureUrl(_currentUrl),
                progress: _tab.progress,
              ),
              TabStrip(
                manager: _tabs,
                onSelect: _selectTab,
                onClose: _closeTab,
                onNew: _newTab,
              ),
            ],
            Expanded(
              child: Stack(
                children: [
                  if (_cosmeticJs == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    TabViewStack(manager: _tabs, builder: _buildTabView),
                  if (_popup != null) _buildPopupView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WebView satu tab + overlay error-nya.
  Widget _buildTabView(BrowserTab tab) {
    return Stack(
      children: [
        InAppWebView(
          initialSettings: buildWebViewSettings(),
          initialUserScripts: UnmodifiableListView([
            _cosmeticUserScript(_cosmeticJs!),
          ]),
          initialUrlRequest: URLRequest(url: WebUri(tab.url)),
          onWebViewCreated: (controller) {
            tab.controller = controller;
            _syncNavState(tab);
          },
          onLoadStart: (c, u) => _onLoadStart(tab, c, u),
          onProgressChanged: (c, p) => _onProgressChanged(tab, c, p),
          onLoadStop: (c, u) => _onLoadStop(tab, c, u),
          onUpdateVisitedHistory: (c, u, r) =>
              _onUpdateVisitedHistory(tab, c, u, r),
          onReceivedError: (c, r, e) => _onReceivedError(tab, c, r, e),
          onEnterFullscreen: _onEnterFullscreen,
          onExitFullscreen: _onExitFullscreen,
          onLongPressHitTestResult: _onLongPress,
          // --- Adblock (M2) ---
          shouldOverrideUrlLoading: (controller, action) async {
            final url = action.request.url?.toString() ?? '';
            Log.d('nav', 'override main=${action.isForMainFrame} $url');
            final decision = _navigationGuard.evaluate(
              url,
              isForMainFrame: action.isForMainFrame,
              sourceUrl: tab.url,
            );
            _navigationGuard.record(decision, url);
            if (decision.blocked) {
              if (decision.reason == 'pinned') _learn(tab, url);
              Log.d('nav', 'diblokir nav: $url (${decision.reason})');
            }
            return decision.blocked
                ? NavigationActionPolicy.CANCEL
                : NavigationActionPolicy.ALLOW;
          },
          shouldInterceptRequest: (controller, request) async =>
              _requestGuard.intercept(request),
          onCreateWindow: (controller, action) async {
            final target = action.request.url?.toString();
            final known =
                target != null && target.isNotEmpty && target != 'about:blank';
            Log.d(
              'popup',
              'onCreateWindow url=$target windowId=${action.windowId}',
            );
            if (known) {
              final result = _popupGuard.handle(
                targetUrl: target,
                currentUrl: tab.url,
              );
              Log.d('popup', 'keputusan: ${result.action} $target');
              if (result.action == PopupAction.block) {
                // URL diketahui = link yang diketuk pengguna (window.open JS
                // selalu null di Android). Buka di tab ini, lewat guard.
                _learn(tab, target);
                final nav = _navigationGuard.evaluate(
                  target,
                  sourceUrl: tab.url,
                );
                if (nav.blocked) {
                  _navigationGuard.record(nav, target);
                } else {
                  _loadUrl(target, tab: tab);
                }
                return false; // transport dibuang, popup tak ada
              }
              // Lolos allowlist: penuhi transport dengan WebView popup agar
              // window.opener halaman asli tetap hidup.
              _openPopup(windowId: action.windowId, decided: true, url: target);
              return true;
            }
            // URL tak diketahui (window.open JS): panel netral dulu, baca URL
            // asli di onLoadStart, baru putuskan blokir/tampil.
            _openPopup(windowId: action.windowId, decided: false);
            return true;
          },
          onConsoleMessage: (controller, message) {
            Log.d('console', '${message.message} [${message.messageLevel}]');
          },
        ),
        if (tab.error != null)
          _ErrorView(
            error: tab.error!,
            onRetry: () => _loadUrl(tab.error!.url, tab: tab),
            onHome: () => _loadUrl(_settings.homeUrl, tab: tab),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onHome,
  });

  final PageError error;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: colors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Tidak bisa memuat halaman', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                error.description,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.outline,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Coba lagi'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onHome,
                    child: const Text('Ke beranda'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
