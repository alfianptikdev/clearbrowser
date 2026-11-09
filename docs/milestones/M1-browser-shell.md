# M1 — Browser Shell + WebView Tuning

| | |
|---|---|
| Status | `DONE` |
| Depends on | — |
| Blocks | M2, M3, M4, M5 |
| Estimasi | 1 sesi (aktual: 1 sesi) |
| File milik | `pubspec.yaml`, `lib/main.dart`, `lib/app.dart`, `lib/core/*`, `lib/browser/browser_page.dart`, `webview_setup.dart`, `address_bar.dart`, `android/**` |

## Tujuan

Aplikasi bisa dijalankan di Android sebagai browser yang layak pakai: buka URL, navigasi, progress, video inline/fullscreen. **Belum ada adblock** — itu M2. Milestone ini menyiapkan fondasi yang benar (settings WebView, konstanta, struktur folder) supaya M2–M4 tinggal menempel guard.

## Prasyarat

- Flutter 3.35.3 terpasang (`flutter --version`).
- Perangkat/emulator Android tersedia untuk smoke test (boleh emulator, validasi situs nyata nanti di M3).

## Task

- [x] `flutter create --org com.alfianptik --project-name cleanbrowser --platforms=android .` di root proyek. Jangan hapus `docs/`.
- [x] `git init` + commit awal berisi dokumen.
- [x] Tambah dependency: `flutter_inappwebview` 6.1.5, `shared_preferences` 2.5.5, `path_provider` 2.1.5, `http` 1.6.0. Tercatat di `docs/ARCHITECTURE.md` §5.
- [x] `android/app/build.gradle.kts`: `minSdk = 24`, `multiDexEnabled = true`, `compileOptions` Java 17.
- [x] `AndroidManifest.xml`: `INTERNET`, `hardwareAccelerated=true`, `usesCleartextTraffic=true`, `largeHeap=true`, `android:label="Clear Browser"`, `configChanges` untuk orientation/screenSize (agar rotasi tidak reload).
- [x] Buat `lib/core/constants.dart`: `AppInfo`, `StorageKeys`, `kDefaultUserAgent`, `kMediaExtensions`, `kMediaCdnHosts`, `kHomeUrl`, `kSearchUrl`, batas log/history/tab.
- [x] Buat `lib/core/logger.dart`: no-op di release, `debugPrint` di debug.
- [x] Buat `lib/core/url_utils.dart`: `normalizeInput()`, `hostOf()`, `isSecureUrl()` (FR-02).
- [x] Buat `lib/browser/webview_setup.dart`: `buildWebViewSettings()`, satu sumber kebenaran.
- [x] Buat `lib/browser/address_bar.dart`: field + back/forward/reload/stop, indikator lock, progress bar.
- [x] Buat `lib/browser/browser_page.dart`: `InAppWebView`, progress, error page, fullscreen handler, back hardware.
- [x] Normalisasi input: tanpa skema → `https://`; spasi / bukan domain → pencarian; `localhost:8080` & IP ditangani benar.
- [x] UA Chrome Android asli diset via settings.
- [x] Siapkan `assets/rules/` + daftarkan di `pubspec.yaml`, isi placeholder `hosts.txt` & `sites.json`.
- [x] Theme Material 3, dark mode default.
- [x] `.gitignore` (template Flutter + `android/.gitignore`) mencakup build, `.dart_tool`, `*.jks`, `key.properties`.
- [x] Test: `test/url_utils_test.dart` (9 kasus) + `test/widget_test.dart` (2 kasus).

## Kriteria selesai

- [x] App terpasang dan terbuka di Android tanpa crash.
- [x] `https://example.com` termuat; address bar menampilkan URL final.
- [x] Input `videy.co` (tanpa skema) membuka `https://videy.co` — diverifikasi lewat unit test; di device diverifikasi dengan `example.com`.
- [x] Input `cara nonton video` membuka hasil pencarian — unit test.
- [x] Back hardware kembali ke halaman sebelumnya; back di halaman pertama keluar app.
- [x] Rotasi layar tidak memuat ulang halaman.
- [x] Video HTML5 main (diverifikasi dengan sample video MDN di emulator).
- [ ] Video fullscreen — **belum terverifikasi di emulator** (kontrol video tidak merespons tap sintetis). Perlu dicek pemilik di perangkat fisik.
- [x] `flutter analyze` 0 issue, `flutter test` 11 lulus.

## Verifikasi

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d <device>
```

## Hasil implementasi (Sesi 1 — 2026-11-09)

**Dibuat/diubah**

| File | Isi |
|---|---|
| `lib/main.dart` | `ensureInitialized`, `setWebContentsDebuggingEnabled` (debug), `runApp` |
| `lib/app.dart` | `MaterialApp`, Material 3, seed `#4C8DFF`, dark default |
| `lib/core/constants.dart` | AppInfo, StorageKeys, UA, media list, URL, batas |
| `lib/core/logger.dart` | `Log.d` / `Log.e` (no-op di release) |
| `lib/core/url_utils.dart` | normalisasi input (deviasi: file tambahan, tidak ada di rencana awal) |
| `lib/browser/webview_setup.dart` | `InAppWebViewSettings` lengkap |
| `lib/browser/address_bar.dart` | UI bar + progress; tombol clear disembunyikan saat loading (perbaikan UX) |
| `lib/browser/browser_page.dart` | page, callback, error view, fullscreen, PopScope |
| `android/app/src/main/AndroidManifest.xml` | permission + atribut aplikasi |
| `android/app/build.gradle.kts` | minSdk 24, Java 17, multiDex |
| `assets/rules/hosts.txt`, `sites.json` | placeholder sesuai `docs/RULES-FORMAT.md` |
| `test/url_utils_test.dart`, `test/widget_test.dart` | 11 test |

**Verifikasi**

- `flutter analyze` → 0 issue; `flutter test` → 11 lulus.
- `flutter build apk --debug` dan `flutter build apk --release` (45,9 MB universal) sukses.
- Emulator Pixel 6 API 35: halaman awal DuckDuckGo termuat, address bar sinkron, navigasi ke `example.com` via soft keyboard (IME Go) dan hardware Enter, tombol back, rotasi landscape tanpa reload, progress bar, tombol stop.
- Video HTML5 diputar dari `mdn.github.io/.../simple-video.html` → frame video tampil (bukan sekadar kontrol).

**Belum terverifikasi / batasan**

- Fullscreen video (`onEnterFullscreen` → chrome tersembunyi) belum terbukti di emulator.
- Autoplay tanpa gesture belum diuji (halaman uji tidak memakai atribut `autoplay`).
- Emulator ini sangat lambat (first frame 23–31 s, `lowmemorykiller` aktif, ANR saat 40 keyevent dikirim sekaligus). ANR tersebut tidak muncul pada pemakaian normal.
- Uji akhir tetap di perangkat fisik pemilik.

## Di luar lingkup

- Adblock, cosmetic filter, tab, history, settings (M2–M4).
- Multi-tab UI.
- Keystore release; boleh tetap memakai debug signing untuk sideload.

## Catatan untuk sesi berikut

- Jangan menambah hook guard di milestone ini; M2 menambahkan `shouldOverrideUrlLoading`/`shouldInterceptRequest` di `browser_controller.dart` (belum dibuat; saat ini callback ada di `browser_page.dart` — pindahkan bila perlu, catat di handoff).
- **Jebakan build:** `flutter build apk` pernah melaporkan sukses dalam <10 s tanpa mengompilasi perubahan (`kernel_blob.bin` tetap timestamp lama). Jika build terasa terlalu cepat, jalankan `flutter clean` dulu. Lihat `AGENTS.md` §5.
- Jebakan input emulator: koordinat `adb input` memakai piksel perangkat (1080×2400), bukan piksel screenshot (900×2000). Tunggu halaman selesai memuat sebelum menyentuh address bar, dan jangan kirim puluhan keyevent sekaligus.
