import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/constants.dart';

/// Satu-satunya sumber kebenaran untuk pengaturan WebView
/// (lihat `docs/ARCHITECTURE.md` §4).
///
/// M2–M3 akan menambah callback guard, tetapi **bukan** mengubah settings ini
/// di tempat lain.
InAppWebViewSettings buildWebViewSettings() {
  return InAppWebViewSettings(
    // --- Inti halaman ---
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    cacheEnabled: true,
    userAgent: kDefaultUserAgent,

    // --- Popup (D6): window baru tidak boleh terbuka otomatis ---
    // true agar window.open() JS sampai ke onCreateWindow, di mana
    // PopupGuard yang memutuskan (allowlist OAuth vs blokir). Bila false,
    // WebView memblokir diam-diam dan callback tidak pernah dipanggil.
    supportMultipleWindows: true,
    javaScriptCanOpenWindowsAutomatically: true,

    // --- Video (FR-03) ---
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    useHybridComposition: true,
    transparentBackground: false,

    // --- Player yang memakai iframe/cookie pihak ketiga ---
    thirdPartyCookiesEnabled: true,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,

    // --- Keamanan dasar ---
    allowFileAccess: false,
    allowContentAccess: false,
    allowFileAccessFromFileURLs: false,
    allowUniversalAccessFromFileURLs: false,
    safeBrowsingEnabled: true,
    upgradeKnownHostsToHTTPS: true,

    // --- Interception: dipakai penuh mulai M2 ---
    useShouldInterceptRequest: true,
    useShouldOverrideUrlLoading: true,
    useOnDownloadStart: true,

    // --- Debug ---
    isInspectable: kDebugMode,

    // --- Tampilan ---
    supportZoom: false,
    verticalScrollBarEnabled: false,
    overScrollMode: OverScrollMode.NEVER,
    disableContextMenu: false,
    allowsBackForwardNavigationGestures: true,
    geolocationEnabled: false,
  );
}
