import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../adblock/block_log.dart';
import '../adblock/navigation_guard.dart';
import '../adblock/popup_guard.dart';
import '../adblock/request_guard.dart';
import '../adblock/rule_engine.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../core/url_utils.dart';
import '../ui/block_log_sheet.dart';
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
    Log.d(
      'adblock',
      'siap: ${_ruleEngine.hostCount} host, '
          '${_ruleEngine.allowlist.length} allowlist',
    );
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
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                isLoading: _isLoading,
                isSecure: isSecureUrl(_currentUrl),
                progress: _progress,
              ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialSettings: buildWebViewSettings(),
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
                      final decision = _navigationGuard.evaluate(
                        url,
                        isForMainFrame: action.isForMainFrame,
                      );
                      _navigationGuard.record(decision, url);
                      return decision.blocked
                          ? NavigationActionPolicy.CANCEL
                          : NavigationActionPolicy.ALLOW;
                    },
                    shouldInterceptRequest: (controller, request) async =>
                        _requestGuard.intercept(request),
                    onCreateWindow: (controller, action) async {
                      final target = action.request.url?.toString();
                      Log.d('popup', 'ditolak: $target');
                      return _popupGuard.handle(
                        targetUrl: target,
                        currentUrl: _currentUrl,
                      );
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
