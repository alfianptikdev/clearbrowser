import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../adblock/block_log.dart';
import '../adblock/cosmetic_script.dart';
import '../adblock/navigation_guard.dart';
import '../adblock/popup_guard.dart';
import '../adblock/request_guard.dart';
import '../adblock/rule_engine.dart';
import '../adblock/site_profiles.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../core/url_utils.dart';
import '../ui/block_log_sheet.dart';
import '../ui/cosmetic_test_page.dart';
import 'address_bar.dart';
import 'webview_setup.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _PageError {
  const _PageError({required this.url, required this.description});

  final String url;
  final String description;
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

  InAppWebViewController? _webView;

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

  String _currentUrl = kHomeUrl;
  double _progress = 0;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isFullscreen = false;
  _PageError? _error;
  _PopupSession? _popup;

  /// Skrip kosmetik (M3). WebView baru dibuat setelah ini siap karena
  /// `initialUserScripts` hanya dibaca saat pembuatan.
  String? _cosmeticJs;
  SiteProfiles _baseProfiles = SiteProfiles.empty();
  final Set<String> _userSites = <String>{};

  @override
  void initState() {
    super.initState();
    _initAdblock();
  }

  /// Dimuat setelah frame pertama agar startup tidak menunggu I/O.
  /// Gagal memuat = adblock kosong, bukan crash (fail-open).
  Future<void> _initAdblock() async {
    await _ruleEngine.loadFromAssets();
    await _ruleEngine.loadAllowlist();
    await _ruleEngine.loadLearned();
    _baseProfiles = await SiteProfiles.load();
    _ruleEngine.setTopLevelBlocked(_baseProfiles.blockTopLevel);
    _ruleEngine.setUrlPatterns(_baseProfiles.globalUrlPatterns);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userSites.addAll(prefs.getStringList(StorageKeys.pinnedSites) ?? []);
    } catch (error) {
      Log.e('adblock', 'gagal memuat situs ditandai', error);
    }
    _applyProfiles();
  }

  UserScript _cosmeticUserScript(String js) => UserScript(
    source: js,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: false,
  );

  /// Gabungkan profil `sites.json` + situs yang ditandai pengguna, lalu
  /// bangun ulang skrip kosmetik dan kunci navigasi.
  void _applyProfiles() {
    final merged = _baseProfiles.withUserSites(_userSites);
    _navigationGuard.profiles = merged;
    final js = CosmeticScript.build(merged);
    if (mounted) setState(() => _cosmeticJs = js);
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
    final added = _userSites.add(site);
    if (!added) _userSites.remove(site);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(StorageKeys.pinnedSites, _userSites.toList());
    } catch (error) {
      Log.e('adblock', 'gagal menyimpan situs ditandai', error);
    }
    _applyProfiles();
    // UserScript hanya berlaku di muatan berikutnya → ganti skrip, muat ulang.
    await _webView?.removeAllUserScripts();
    await _webView?.addUserScript(
      userScript: _cosmeticUserScript(_cosmeticJs!),
    );
    await _webView?.reload();
    messenger.showSnackBar(
      SnackBar(
        content: Text(added ? '$site ditandai situs video' : '$site dilepas'),
      ),
    );
  }

  /// Host iklan dipelajari hanya bila dibuka dari halaman video terkunci.
  void _learn(String url) {
    if (!_navigationGuard.shouldLearn(_currentUrl, url)) return;
    final host = hostOf(url);
    if (host.isNotEmpty) unawaited(_ruleEngine.learn(host));
  }

  @override
  void dispose() {
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

  Future<void> _loadUrl(String url) async {
    Log.d('nav', 'loadUrl $url');
    _urlController.text = url;
    if (mounted) {
      setState(() {
        _error = null;
        _isLoading = true;
        _progress = 0;
        _currentUrl = url;
      });
    }
    try {
      await _webView?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } catch (error) {
      Log.e('nav', 'loadUrl gagal: $url', error);
    }
  }

  void _setUrl(String url) {
    if (url.isEmpty || url == 'about:blank') return;
    if (!_focusNode.hasFocus && _urlController.text != url) {
      _urlController.text = url;
    }
    if (url == _currentUrl) return;
    setState(() => _currentUrl = url);
  }

  Future<void> _syncNavState([InAppWebViewController? controller]) async {
    final webView = controller ?? _webView;
    if (webView == null) return;
    final canGoBack = await webView.canGoBack();
    final canGoForward = await webView.canGoForward();
    if (!mounted) return;
    if (canGoBack == _canGoBack && canGoForward == _canGoForward) return;
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _handleBack() async {
    if (_isFullscreen) {
      setState(() => _isFullscreen = false);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }
    final webView = _webView;
    if (webView != null && await webView.canGoBack()) {
      await webView.goBack();
    } else {
      await SystemNavigator.pop();
    }
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
      _learn(target);
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

  void _onLoadStart(InAppWebViewController controller, WebUri? url) {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _progress = 0;
      _error = null;
    });
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    if (!mounted) return;
    setState(() => _progress = (progress / 100).clamp(0.0, 1.0));
  }

  Future<void> _onLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _progress = 1;
    });
    final current = await controller.getUrl();
    if (!mounted) return;
    if (current != null) _setUrl(current.toString());
    await _syncNavState(controller);
  }

  void _onUpdateVisitedHistory(
    InAppWebViewController controller,
    WebUri? url,
    bool? isReload,
  ) {
    if (url != null) _setUrl(url.toString());
    _syncNavState(controller);
  }

  void _onReceivedError(
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
      _isLoading = false;
      _progress = 0;
      _error = _PageError(
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
            if (!_isFullscreen)
              AddressBar(
                controller: _urlController,
                focusNode: _focusNode,
                onSubmitted: _submit,
                onBack: () => _webView?.goBack(),
                onForward: () => _webView?.goForward(),
                onReload: () => _webView?.reload(),
                onStop: () => _webView?.stopLoading(),
                onMenu: _openBlockLog,
                onTogglePin: _togglePin,
                isPinned: _navigationGuard.isPinned(_currentUrl),
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                isLoading: _isLoading,
                isSecure: isSecureUrl(_currentUrl),
                progress: _progress,
              ),
            Expanded(
              child: Stack(
                children: [
                  if (_cosmeticJs == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    InAppWebView(
                      initialSettings: buildWebViewSettings(),
                      initialUserScripts: UnmodifiableListView([
                        UserScript(
                          source: _cosmeticJs!,
                          injectionTime:
                              UserScriptInjectionTime.AT_DOCUMENT_START,
                          forMainFrameOnly: false,
                        ),
                      ]),
                      initialUrlRequest: URLRequest(url: WebUri(kHomeUrl)),
                      onWebViewCreated: (controller) {
                        _webView = controller;
                        _syncNavState(controller);
                      },
                      onLoadStart: _onLoadStart,
                      onProgressChanged: _onProgressChanged,
                      onLoadStop: _onLoadStop,
                      onUpdateVisitedHistory: _onUpdateVisitedHistory,
                      onReceivedError: _onReceivedError,
                      onEnterFullscreen: _onEnterFullscreen,
                      onExitFullscreen: _onExitFullscreen,
                      // --- Adblock (M2) ---
                      shouldOverrideUrlLoading: (controller, action) async {
                        final url = action.request.url?.toString() ?? '';
                        Log.d(
                          'nav',
                          'override main=${action.isForMainFrame} $url',
                        );
                        final decision = _navigationGuard.evaluate(
                          url,
                          isForMainFrame: action.isForMainFrame,
                        );
                        _navigationGuard.record(decision, url);
                        if (decision.blocked) {
                          if (decision.reason == 'pinned') _learn(url);
                          Log.d(
                            'nav',
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
                        final target = action.request.url?.toString();
                        final known =
                            target != null &&
                            target.isNotEmpty &&
                            target != 'about:blank';
                        Log.d(
                          'popup',
                          'onCreateWindow url=$target '
                              'windowId=${action.windowId}',
                        );
                        if (known) {
                          final result = _popupGuard.handle(
                            targetUrl: target,
                            currentUrl: _currentUrl,
                          );
                          Log.d('popup', 'keputusan: ${result.action} $target');
                          if (result.action == PopupAction.block) {
                            // URL diketahui = link yang diketuk pengguna
                            // (window.open JS selalu null di Android). Buka di
                            // tab ini, tetap lewat navigation guard.
                            _learn(target);
                            final nav = _navigationGuard.evaluate(
                              target,
                              sourceUrl: _currentUrl,
                            );
                            if (nav.blocked) {
                              _navigationGuard.record(nav, target);
                            } else {
                              _loadUrl(target);
                            }
                            return false; // transport dibuang, popup tak ada
                          }
                          // Lolos allowlist: penuhi transport dengan WebView
                          // popup agar window.opener halaman asli tetap hidup.
                          _openPopup(
                            windowId: action.windowId,
                            decided: true,
                            url: target,
                          );
                          return true;
                        }
                        // URL tak diketahui (window.open JS; Android tidak
                        // menyampaikannya): buka panel netral lebih dulu, baca
                        // URL asli di onLoadStart, baru putuskan blokir/tampil.
                        _openPopup(windowId: action.windowId, decided: false);
                        return true;
                      },
                      onConsoleMessage: (controller, message) {
                        Log.d(
                          'console',
                          '${message.message} [${message.messageLevel}]',
                        );
                      },
                    ),
                  if (_error != null)
                    _ErrorView(
                      error: _error!,
                      onRetry: () => _loadUrl(_error!.url),
                      onHome: () => _loadUrl(kHomeUrl),
                    ),
                  if (_popup != null) _buildPopupView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onHome,
  });

  final _PageError error;
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
