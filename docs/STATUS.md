# STATUS — Clear Browser

**Berkas ini wajib di-update di akhir setiap sesi agent.** Ini satu-satunya sumber kebenaran tentang "sudah sampai mana".

Terakhir diperbarui: 2026-11-10 · Sesi: 3 (M2 lanjutan + M3 + M4)

## 1. Papan milestone

| # | Milestone | Status | Sesi | Commit | Catatan |
|---|---|---|---|---|---|
| M1 | Browser shell + WebView tuning | `DONE` | 1 | `6ebcc02` | Fullscreen video belum diuji di device fisik |
| M2 | Adblock jaringan + navigasi + popup + log | `IN_PROGRESS` | 2–3 | — | Diuji pemilik di device (SM A525F): popup diblokir, link `t.co`→`filecoster.com` terbuka, video play, redirect iklan diblokir. Belum commit |
| M3 | Cosmetic engine + site profile | `IN_PROGRESS` | 3 | — | Kode + 61 test lulus; video play & iklan terblokir di device (pemilik). Harness `cb:test` dan Doodstream/Videy belum dikonfirmasi |
| M4 | Rule pack remote + settings + history/tab | `IN_PROGRESS` | 3 | — | Kode + 76 test lulus; uji manual device oleh pemilik berjalan. URL rule pack belum dikonfigurasi (Update tersembunyi) |
| M5 | Mode Video Bersih (native player) | `TODO` | — | — | Opsional, v1.1 |

Legenda: `TODO` · `IN_PROGRESS` · `BLOCKED` · `DONE`

## 2. Sesi berikutnya

Pemilik menguji M4 di device (tab, Settings, bookmark, history, toggle global, harness `cb:test`, Doodstream/Videy) lalu melapor kendala di sesi baru. Setelah lolos: tandai M2–M4 `DONE`. Isi URL rule pack (`assets/rules/version.json`) untuk menguji Update.

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

| D8 | D6 dilonggarkan: popup allowlist `accounts.google.com` tampil sebagai panel (OAuth x.com) | Login Google di x.com memakai `window.open` | 2026-11-10 |
| D9 | Link diketuk (URL popup diketahui) dibuka di tab yang sama, lewat NavigationGuard; popup JS (URL `null`) tetap diblokir | Link `t.co` di timeline x.com | 2026-11-10 |
| D10 | Halaman dengan profil `sites.json` / ditandai pengguna "terkunci": navigasi top-level lintas situs diblokir; skema app kustom (`shopeeid:` dll.) di top-level diblokir; host iklan dari halaman terkunci dipelajari otomatis (prefs `rules.learnedHosts`) | Redirect iklan ke jaringan yang tak ada di `hosts.txt`; daftar manual tidak skalabel | 2026-11-10 |

Perubahan keputusan harus dicatat di sini dengan alasan, bukan diam-diam di kode.

## 4. Log sesi

Format: `Sesi N — Mx — hasil — commit — catatan`

| Sesi | Milestone | Hasil | Commit | Catatan |
|---|---|---|---|---|
| 0 | docs | PRD, arsitektur, 5 milestone, AGENTS.md dibuat | — | Belum ada kode |
| 1 | M1 | Shell browser jalan: WebView, address bar, progress, error view, normalisasi URL, fullscreen hook, 11 test | `6ebcc02` | Kode callback masih di `browser_page.dart` (belum `browser_controller.dart`) |
| 2 | M2 | Lapisan adblock: rule engine (3560 host Peter Lowe + 8 manual), navigasi guard, request guard, popup guard (D6), blokir log + sheet, tombol menu perisai, 31 test baru | — | Kode test & build lulus. Uji device fisik Doodstream/Videy belum — emulator ANR-berulang di host 2015, tidak bisa melanjutkan manual UI di emulator |
| 3 | M2+M3 | Perbaiki login Google x.com, link `t.co`; M3: `site_profiles`, `cosmetic_script`, `sites.json`, harness `cb:test`; pin situs video, belajar host iklan, kunci navigasi; 61 test | — | Diuji pemilik di device; log dibaca via `adb logcat` |
| 3 | M4 | Rule pack loader (cache→asset, update tervalidasi, atomik), Settings, history/bookmark/settings store, multi-tab (maks 10, IndexedStack), menu ⋮; 76 test | — | Uji device belum dikonfirmasi; `flutter run` terputus saat layar HP mati (pakai Stay awake / `adb logcat`) |

## 5. Masalah yang diketahui

| # | Masalah | Status | Solusi sementara |
|---|---|---|---|
| 1 | Video fullscreen belum terbukti (kontrol video tak merespons tap sintetis di emulator) | Terbuka | Verifikasi manual pemilik di perangkat fisik |
| 2 | Emulator host lambat (first frame 23–31 s, `lowmemorykiller` aktif, ANR saat puluhan keyevent sintetis / reboot emulator) | Lingkungan | Jangan pakai emulator untuk uji beban; uji akhir di device pemilik |
| 3 | `flutter build apk` bisa "sukses" cepat tanpa mengompilasi perubahan (cache Gradle basi) | Diketahui | Jalankan `flutter clean` bila build < 10 s padahal kode berubah |
| 4 | `assets/rules/hosts.txt` diisi (M2) — selesai | Selesai | 3568 baris (3560 Peter Lowe + 8 manual) |
| 5 | Login Google di x.com tak merespons (popup `window.open` ditolak D6) | Fix, diuji pemilik | `PopupGuard` allowlist `accounts.google.com`. TODO: pindahkan allowlist ke `assets/rules/` (aturan 3 AGENTS) |
| 6 | `flutter run` memasang APK basi (build ~7 s, kode baru tak masuk) — terjadi 3× di sesi 3 | Diketahui | `flutter clean` lalu run; cek `kernel_blob.bin` di APK (`grep -a` string baru) |
| 7 | Host terpelajari/situs ditandai belum bisa dilihat/dihapus | Terbuka | Allowlist menang atas host terpelajari; layar kelola di M4 |
| 8 | Link sah yang diketuk di halaman terkunci ikut dipelajari sebagai iklan | Terbuka | Allowlist pengguna |
| 9 | `RuleEngine.siteOf` heuristik panjang label, bukan public-suffix-list | Diketahui | Cukup untuk TLD `.co.id`-style |
| 10 | URL rule pack kosong → tombol Update tersembunyi, kriteria Update/mode pesawat belum bisa dibuktikan di device | Terbuka | Isi `hostsUrl`/`sitesUrl` di `assets/rules/version.json` atau `core/constants.dart` |
| 11 | Persist daftar tab (opsional M4) dan ETag update belum dibuat | Ditunda | `// shortcut:` di `rule_pack_loader.dart`; tab hilang saat app ditutup |

## 6. Catatan handoff terakhir

### Sesi 2 — M2 dikerjakan, belum selesai
- Yang dibuat: `lib/adblock/{rule_engine,block_log,navigation_guard,request_guard,popup_guard}.dart`, `lib/ui/block_log_sheet.dart`, `assets/rules/hosts.txt` (3568 baris), `lib/browser/address_bar.dart` (tombol menu perisai + log sheet), `lib/browser/browser_page.dart` (hook guard 3 callback), `test/rule_engine_test.dart` (21 test), `test/block_log_test.dart` (4 test).
- Verifikasi: `flutter analyze` 0 issue · `flutter test` 42 lulus · `flutter build apk --release` sukses (47,4 MB) · emulator: 3560 host dimuat, popup `window.open()` tidak terbuka (D6 OK), `ERR_CONNECTION_REFUSED` pada host di blocklist.
- Belum teruji: semua uji di perangkat fisik (Doodstream/Videy), tombol Allow dari log sheet, navigasi top-level `blockTopLevel` (belum ada entri di `sites.json` di M2).
- Catatan untuk sesi berikut: `browser_controller.dart` masih belum dibuat — guard tetap dihubungkan langsung di `browser_page.dart`. Refactor ke controller ditunda ke M4 (tab_manager) supaya M2 tetap cepat.
- Commit: belum ada commit M2; siap commit setelah uji device fisik selesai atau sesi dipaksa berakhir.

### Sesi 3 — M2 lanjutan + M3 (belum DONE)
- Yang dibuat: M3 `lib/adblock/{site_profiles,cosmetic_script}.dart`, `assets/rules/sites.json` (7 situs + `blockTopLevel`), `lib/ui/cosmetic_test_page.dart` (debug, ketik `cb:test`), tes `site_profiles_test` + `learning_test`; M2 `popup_guard` (allowlist OAuth), `navigation_guard` (kunci halaman video, skema app), `rule_engine` (host terpelajari, `siteOf`), `browser_page` (panel popup, pin, belajar), `address_bar` (tombol pin), `hosts.txt` (+5 host iklan).
- Verifikasi: analyze 0 issue · test 61 lulus · manual (pemilik, SM A525F): login Google x.com, `t.co`→`filecoster.com`, video play, iklan terblokir.
- Belum teruji: harness `cb:test`; Doodstream/Videy asli; selector `sites.json` (best-effort, kosong untuk filecoster/vqko); toggle `enabled`/`stealth` di prefs (ditunda M4).
- Catatan untuk sesi berikut: satu skrip memuat semua profil dan memilih lewat `location.hostname`; host tanpa profil tidak disentuh skrip. `build()` menerima `SiteProfiles`, bukan satu `SiteProfile` (beda dari task M3). Allowlist `accounts.google.com` masih di Dart (pindah ke assets). Waspada cache build basi (masalah #6).
- Commit: belum.

### Sesi 3 (lanjutan) — M4 dikerjakan, belum DONE
- Yang dibuat: `lib/adblock/rule_pack_loader.dart`, `assets/rules/version.json`, `lib/data/{history,bookmark,settings}_store.dart`, `lib/ui/settings_page.dart`, `lib/browser/{tab_manager,tab_view_stack}.dart`, `browser_page.dart` per-tab, menu ⋮ di `address_bar.dart`; `RuleEngine.enabled/unlearn`, `PopupGuard.enabled`, `SiteProfiles.withOverrides`; test `rule_pack_loader`, `data_stores`, `tab_manager`.
- Verifikasi: analyze 0 issue · test 76 lulus · APK terpasang di SM A525F (isi kernel diverifikasi).
- Belum teruji: semua kriteria M4 di device (pemilik menguji manual); Update rule pack nyata (tanpa URL); mode pesawat; memori 3 tab 1080p (NFR-03).
- Catatan untuk sesi berikut: `browser_controller.dart` tetap belum dibuat (state per-tab ada di `BrowserTab`). Toggle Settings memuat ulang tab aktif. `flutter run` putus saat layar mati; cache build basi → `flutter clean` + cek `kernel_blob.bin`.
- Commit: lihat git log.
