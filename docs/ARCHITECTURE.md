# Arsitektur — Clear Browser

Dokumen ini menjelaskan **di mana kode diletakkan dan bagaimana data mengalir**. Baca hanya bagian yang relevan dengan milestone yang sedang dikerjakan.

## 1. Lapisan

```
┌─────────────────────────────────────────────────┐
│ UI Flutter                                      │
│  BrowserPage · AddressBar · TabViewStack        │
│  SettingsPage · BlockLogSheet                   │
└───────────────────────┬─────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────┐
│ BrowserController                               │
│  InAppWebViewSettings · tab lifecycle · state   │
└───────────────────────┬─────────────────────────┘
                        │ callbacks
┌───────────────────────▼─────────────────────────┐
│ Adblock Layer                                   │
│  NavigationGuard  (shouldOverrideUrlLoading)    │
│  RequestGuard     (shouldInterceptRequest)      │
│  PopupGuard       (onCreateWindow)              │
│  CosmeticScript   (UserScript inject)           │
│       └── RuleEngine ← RulePack ← assets/remote │
└───────────────────────┬─────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────┐
│ Data: PrefsStore · HistoryStore · BookmarkStore │
└─────────────────────────────────────────────────┘
```

## 2. Alur request

### 2.1 Navigasi (top-level, klik link / redirect)

```
shouldOverrideUrlLoading(url)
  1. skema bukan http/https?
       intent://, market://, itms-apps://, tel:, sms:  → BLOCK (+log)
       about:, blob:, data:                            → ALLOW
  2. host ∈ allowlist pengguna?                        → ALLOW
  3. host ∈ blockTopLevel (daftar kecil host iklan murni)? → BLOCK (+log)
  4. selain itu                                       → ALLOW
```

Catatan: blocklist besar **tidak** dipakai untuk top-level, supaya pengguna tidak terjebak tidak bisa membuka halaman yang sah.

### 2.2 Subresource

```
shouldInterceptRequest(request)
  0. isForMainFrame?                          → ALLOW (ditangani 2.1)
  1. skema blob:/data:/about:?                → ALLOW
  2. URL media (lihat FR-16) atau host CDN video? → ALLOW   ← WAJIB, jangan diubah
  3. host ∈ allowlist?                        → ALLOW
  4. host ∈ blocklist (suffix match)?         → BLOCK + log
  5. else                                     → ALLOW
```

BLOCK = kembalikan `WebResourceResponse` dengan body kosong, `200`, `text/plain`.

### 2.3 Popup

```
settings: supportMultipleWindows = true,
          javaScriptCanOpenWindowsAutomatically = false
onCreateWindow → return false (tidak membuat WebView baru) + log
```

Konsekuensi: `target=_blank` juga ikut ditolak. Kompensasi: klik panjang / menu "Buka di sini" tetap bisa membuka URL yang sama di tab aktif. Jangan aktifkan kembali `supportMultipleWindows` tanpa alasan kuat.

### 2.4 Cosmetic (JS)

```
AT_DOCUMENT_START → IIFE, tanpa variabel global:
  a. window.open = () => null
  b. window.onbeforeunload = null
  c. capture-phase click guard (isTrusted, cross-origin target=_blank)
  d. pasang MutationObserver (debounce 300 ms)
  e. sweep: DOMContentLoaded, load, +1500 ms
```

Skoring overlay (generic): `fixed|absolute` + `z-index ≥ 1000` + luas ≥ 25% viewport + mengandung iframe/link eksternal + bukan ancestor/descendant `<video>`/container player. Skor ≥ 3 → sembunyikan, lalu klik tombol close asli.

## 3. Struktur direktori

```
lib/
  main.dart                  # entry, init prefs + rule pack
  app.dart                   # MaterialApp, theme, routing
  core/
    constants.dart           # UA, URL rule pack, storage keys, media ext
    logger.dart              # debug-only logging
    url_utils.dart           # normalisasi input address bar (FR-02)
  browser/
    browser_page.dart        # halaman utama
    browser_controller.dart  # state + InAppWebView lifecycle
    webview_setup.dart       # InAppWebViewSettings (satu sumber kebenaran)
    address_bar.dart
    tab_manager.dart
    tab_view_stack.dart
  adblock/
    rule_engine.dart         # suffix match, media bypass, URL patterns
    navigation_guard.dart
    request_guard.dart
    popup_guard.dart
    cosmetic_script.dart     # builder JS dari site profile
    site_profiles.dart       # model + parser sites.json
    rule_pack_loader.dart    # asset + remote fetch + cache
    block_log.dart           # ring buffer + stream
  data/
    prefs_store.dart
    history_store.dart
    bookmark_store.dart
  media/                     # M5
    media_sniffer.dart
    player_page.dart
  ui/
    settings_page.dart
    block_log_sheet.dart
assets/rules/
  hosts.txt
  sites.json
  version.json
test/
  rule_engine_test.dart
  site_profiles_test.dart
  fixtures/
```

## 4. Sumber kebenaran

| Hal | Lokasi | Jangan diduplikasi di |
|---|---|---|
| `InAppWebViewSettings` | `browser/webview_setup.dart` | page, controller |
| Daftar ekstensi media | `core/constants.dart` | guard mana pun |
| Selector situs | `assets/rules/sites.json` | Dart, JS |
| Daftar host iklan | `assets/rules/hosts.txt` | Dart |
| Storage key | `core/constants.dart` | store |

## 5. Runtime & dependensi

| Komponen | Versi | Catatan |
|---|---|---|
| Flutter | 3.35.3 (stable) | Jangan upgrade mayor di tengah milestone |
| Dart | 3.9.2 | — |
| Java | 21 | AGP 8.x |
| `flutter_inappwebview` | ^6.1.5 | inti |
| `shared_preferences` | ^2.5.5 | setting kecil |
| `path_provider` | ^2.1.5 | cache rule pack |
| `http` | ^1.6.0 | unduh rule pack |
| `media_kit` + `_video` + `libs_android_video` | M5 | HLS/mp4 native |

`flutter pub add` saat M1 untuk memastikan versi terbaru yang kompatibel; perbarui tabel ini bila berbeda.

## 6. Penyimpanan

| Key | Tipe | Isi |
|---|---|---|
| `settings.adblockEnabled` | bool | toggle global |
| `settings.allowlist` | `List<String>` | host yang diizinkan |
| `settings.siteOverrides` | `Map<String,bool>` | toggle per-situs |
| `rules.hosts` | String | isi hosts.txt aktif (cache) |
| `rules.sites` | String | isi sites.json aktif (cache) |
| `rules.version` | String | versi + tanggal rule pack |
| `history.v1` | String | JSON list, maks 500 |
| `bookmarks.v1` | String | JSON list |
| `tabs.v1` | String | JSON list URL tab terakhir (opsional) |

## 7. Kegagalan & fallback

| Kejadian | Perilaku |
|---|---|
| Rule pack remote gagal diunduh | Pakai cache; cache kosong → asset bawaan |
| `sites.json` tidak valid | Abaikan file remote, pakai asset, catat di log debug |
| Rule engine melempar exception | Fail-open: request diloloskan |
| WebView crash / proses mati | `onRenderProcessGone` → reload tab, tampilkan snackbar |
| Halaman butuh cookie pihak ketiga | `thirdPartyCookiesEnabled: true` |

## 8. Batasan teknis yang sudah diketahui

- `shouldInterceptRequest` hanya berjalan di Android (iOS butuh `ContentBlocker`). Ini alasan keputusan D1.
- Android WebView tidak selalu mendukung HLS di `<video>`; karena itu M5 ada.
- `setSupportMultipleWindows(true)` dibutuhkan agar `onCreateWindow` bisa dipanggil.
- JS injection tidak bisa dijamin berjalan sebelum inline script situs; urutan override harus di `AT_DOCUMENT_START`, bukan `AT_DOCUMENT_END`.
