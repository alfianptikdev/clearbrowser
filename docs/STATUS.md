# STATUS — Clear Browser

**Berkas ini wajib di-update di akhir setiap sesi agent.** Ini satu-satunya sumber kebenaran tentang "sudah sampai mana".

Terakhir diperbarui: 2026-11-09 · Sesi: 1 (M1)

## 1. Papan milestone

| # | Milestone | Status | Sesi | Commit | Catatan |
|---|---|---|---|---|---|
| M1 | Browser shell + WebView tuning | `DONE` | 1 | `2f5c6d2` | Fullscreen video belum diuji di device fisik |
| M2 | Adblock jaringan + navigasi + popup + log | `TODO` | — | — | Siap dikerjakan |
| M3 | Cosmetic engine + site profile | `TODO` | — | — | Butuh M2 |
| M4 | Rule pack remote + settings + history/tab | `TODO` | — | — | Butuh M3 |
| M5 | Mode Video Bersih (native player) | `TODO` | — | — | Opsional, v1.1 |

Legenda: `TODO` · `IN_PROGRESS` · `BLOCKED` · `DONE`

## 2. Sesi berikutnya

**Kerjakan: M2** (`docs/milestones/M2-network-adblock.md`). Batas sesi: `lib/adblock/**`, `assets/rules/hosts.txt`, `lib/ui/block_log_sheet.dart`, `test/rule_engine_test.dart` + hook satu baris di `browser_page.dart`.

## 3. Keputusan yang sudah final

| ID | Keputusan | Alasan | Tanggal |
|---|---|---|---|
| D1 | Android dulu, iOS tidak di v1 | `shouldInterceptRequest` hanya ada di Android; iOS butuh jalur ContentBlocker terpisah | 2026-11-09 |
| D2 | Adblock dulu (M1–M4), Mode Video Bersih (M5) hanya jika terbukti perlu | Validasi masalah nyata sebelum menambah kompleksitas native player | 2026-11-09 |
| D3 | Distribusi sideload APK, bukan store | Bebas aturan konten & update rule cepat | 2026-11-09 |
| D4 | Fail-open: error rule engine → request lolos | Video mati lebih buruk daripada iklan lolos | 2026-11-09 |
| D5 | Selector & host 100% di rule pack, bukan Dart | Bisa perbaiki situs tanpa rilis ulang | 2026-11-09 |
| D6 | Popup blocker menolak semua window baru | `target=_blank` ikut tertolak, tapi iklan popunder adalah masalah utama | 2026-11-09 |
| D7 | Nama app "Clear Browser", project `cleanbrowser`, package `com.alfianptik.cleanbrowser` | Permintaan pemilik | 2026-11-09 |

Perubahan keputusan harus dicatat di sini dengan alasan, bukan diam-diam di kode.

## 4. Log sesi

Format: `Sesi N — Mx — hasil — commit — catatan`

| Sesi | Milestone | Hasil | Commit | Catatan |
|---|---|---|---|---|
| 0 | docs | PRD, arsitektur, 5 milestone, AGENTS.md dibuat | — | Belum ada kode |
| 1 | M1 | Shell browser jalan: WebView, address bar, progress, error view, normalisasi URL, fullscreen hook, 11 test | `2f5c6d2` | Kode callback masih di `browser_page.dart` (belum `browser_controller.dart`) |

## 5. Masalah yang diketahui

| # | Masalah | Status | Solusi sementara |
|---|---|---|---|
| 1 | Video fullscreen belum terbukti (kontrol video tak merespons tap sintetis di emulator) | Terbuka | Verifikasi manual pemilik di perangkat fisik |
| 2 | Emulator host lambat (first frame 23–31 s, `lowmemorykiller` aktif, ANR saat puluhan keyevent sintetis) | Lingkungan | Jangan pakai emulator untuk uji beban; uji akhir di device pemilik |
| 3 | `flutter build apk` bisa "sukses" cepat tanpa mengompilasi perubahan (cache Gradle basi) | Diketahui | Jalankan `flutter clean` bila build < 10 s padahal kode berubah |
| 4 | `assets/rules/hosts.txt` masih placeholder | Dijadwalkan | Diisi di M2 |

## 6. Catatan handoff terakhir

### Sesi 1 — M1 selesai
- Yang dibuat: `lib/main.dart`, `lib/app.dart`, `lib/core/{constants,logger,url_utils}.dart`, `lib/browser/{webview_setup,address_bar,browser_page}.dart`, konfigurasi Android (minSdk 24, Java 17, multiDex, INTERNET, cleartext, largeHeap, label), placeholder `assets/rules/*`, 11 test.
- Verifikasi: `flutter analyze` 0 issue · `flutter test` 11 lulus · `flutter build apk --debug` & `--release` sukses · emulator Pixel 6 API 35: home DuckDuckGo, navigasi `example.com`, back, rotasi tanpa reload, progress bar, video HTML5 diputar.
- Belum teruji: fullscreen video (emulator), autoplay tanpa gesture, dan semua uji di perangkat fisik.
- Catatan untuk sesi berikut: `browser_controller.dart` belum ada — callback WebView masih langsung di `browser_page.dart`. Saat M2 menambah guard, tambahkan hook seminimal mungkin di file itu dan catat di handoff; jangan refactor besar di tengah M2.
- Commit: `2f5c6d2` feat(M1): browser shell, WebView tuning, address bar, url normalizer
