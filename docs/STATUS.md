# STATUS — Clear Browser

**Berkas ini wajib di-update di akhir setiap sesi agent.** Ini satu-satunya sumber kebenaran tentang "sudah sampai mana".

Terakhir diperbarui: 2026-11-10 · Sesi: 2 (M2)

## 1. Papan milestone

| # | Milestone | Status | Sesi | Commit | Catatan |
|---|---|---|---|---|---|
| M1 | Browser shell + WebView tuning | `DONE` | 1 | `6ebcc02` | Fullscreen video belum diuji di device fisik |
| M2 | Adblock jaringan + navigasi + popup + log | `IN_PROGRESS` | 2 | — | Kode + test lulus; uji Doodstream/Videy di device fisik belum dilakukan |
| M3 | Cosmetic engine + site profile | `TODO` | — | — | Butuh M2 |
| M4 | Rule pack remote + settings + history/tab | `TODO` | — | — | Butuh M3 |
| M5 | Mode Video Bersih (native player) | `TODO` | — | — | Opsional, v1.1 |

Legenda: `TODO` · `IN_PROGRESS` · `BLOCKED` · `DONE`

## 2. Sesi berikutnya

Lanjutkan M2: uji Doodstream/Videy di perangkat fisik pemilik. Belum ada pekerjaan baru.

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
| 1 | M1 | Shell browser jalan: WebView, address bar, progress, error view, normalisasi URL, fullscreen hook, 11 test | `6ebcc02` | Kode callback masih di `browser_page.dart` (belum `browser_controller.dart`) |
| 2 | M2 | Lapisan adblock: rule engine (3560 host Peter Lowe + 8 manual), navigasi guard, request guard, popup guard (D6), blokir log + sheet, tombol menu perisai, 31 test baru | — | Kode test & build lulus. Uji device fisik Doodstream/Videy belum — emulator ANR-berulang di host 2015, tidak bisa melanjutkan manual UI di emulator |

## 5. Masalah yang diketahui

| # | Masalah | Status | Solusi sementara |
|---|---|---|---|
| 1 | Video fullscreen belum terbukti (kontrol video tak merespons tap sintetis di emulator) | Terbuka | Verifikasi manual pemilik di perangkat fisik |
| 2 | Emulator host lambat (first frame 23–31 s, `lowmemorykiller` aktif, ANR saat puluhan keyevent sintetis / reboot emulator) | Lingkungan | Jangan pakai emulator untuk uji beban; uji akhir di device pemilik |
| 3 | `flutter build apk` bisa "sukses" cepat tanpa mengompilasi perubahan (cache Gradle basi) | Diketahui | Jalankan `flutter clean` bila build < 10 s padahal kode berubah |
| 4 | `assets/rules/hosts.txt` diisi (M2) — selesai | Selesai | 3568 baris (3560 Peter Lowe + 8 manual) |

## 6. Catatan handoff terakhir

### Sesi 2 — M2 dikerjakan, belum selesai
- Yang dibuat: `lib/adblock/{rule_engine,block_log,navigation_guard,request_guard,popup_guard}.dart`, `lib/ui/block_log_sheet.dart`, `assets/rules/hosts.txt` (3568 baris), `lib/browser/address_bar.dart` (tombol menu perisai + log sheet), `lib/browser/browser_page.dart` (hook guard 3 callback), `test/rule_engine_test.dart` (21 test), `test/block_log_test.dart` (4 test).
- Verifikasi: `flutter analyze` 0 issue · `flutter test` 42 lulus · `flutter build apk --release` sukses (47,4 MB) · emulator: 3560 host dimuat, popup `window.open()` tidak terbuka (D6 OK), `ERR_CONNECTION_REFUSED` pada host di blocklist.
- Belum teruji: semua uji di perangkat fisik (Doodstream/Videy), tombol Allow dari log sheet, navigasi top-level `blockTopLevel` (belum ada entri di `sites.json` di M2).
- Catatan untuk sesi berikut: `browser_controller.dart` masih belum dibuat — guard tetap dihubungkan langsung di `browser_page.dart`. Refactor ke controller ditunda ke M4 (tab_manager) supaya M2 tetap cepat.
- Commit: belum ada commit M2; siap commit setelah uji device fisik selesai atau sesi dipaksa berakhir.
