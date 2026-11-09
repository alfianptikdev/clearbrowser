# M2 — Adblock Jaringan + Navigasi + Popup + Log

| | |
|---|---|
| Status | `TODO` |
| Depends on | M1 |
| Blocks | M3 (butuh `RuleEngine` & `BlockLog`) |
| Estimasi | 1–2 sesi |
| File milik | `lib/adblock/rule_engine.dart`, `request_guard.dart`, `navigation_guard.dart`, `popup_guard.dart`, `block_log.dart`, `assets/rules/hosts.txt`, `lib/ui/block_log_sheet.dart`, `test/rule_engine_test.dart` |

## Tujuan

Memblokir iklan di level request dan navigasi, plus popup — **tanpa merusak video**. Semua keputusan tercatat dan bisa dibatalkan pengguna. Cosmetic filter (overlay DOM) belum ada; itu M3.

## Prasyarat

- M1 `DONE`: WebView sudah berjalan dan settings terpusat di `webview_setup.dart`.

## Task

### Rule engine

- [ ] `rule_engine.dart`:
  - [ ] `loadFromAssets()` memuat `assets/rules/hosts.txt` → `Set<String>`.
  - [ ] `isBlockedHost(String host)`: lowercase, buang port, cocokkan suffix per label maks 4 iterasi. `ads.doubleclick.net` cocok, `notdoubleclick.net` tidak.
  - [ ] `isMediaUrl(Uri)`: ekstensi di `kMediaExtensions` **dan** host CDN video yang di-hardcode di `constants.dart` (mis. `googlevideo.com`, `cloudflarestream.com`, `videy.co`). Case-insensitive.
  - [ ] `isAllowlisted(String host)`, `addToAllowlist`, `removeFromAllowlist` (persist via `SharedPreferences`).
  - [ ] `evaluate(RequestKind, Uri)` → `BlockDecision {bool blocked, String reason, String rule}`. Fail-open: exception ditangkap → `blocked: false, reason: 'error'`.

### Guard

- [ ] `navigation_guard.dart` sesuai `docs/ARCHITECTURE.md` §2.1:
  - [ ] blokir skema `intent`, `market`, `itms-apps`, `tel`, `sms`, `file`.
  - [ ] izinkan `about`, `blob`, `data`.
  - [ ] blocklist **tidak** berlaku untuk top-level; hanya `blockTopLevel` (dari `sites.json`, boleh dibaca kosong di M2).
- [ ] `request_guard.dart` sesuai §2.2, early-out berurutan. Return `WebResourceResponse` kosong (`text/plain`, status 200, `Uint8List(0)`).
- [ ] `popup_guard.dart` sesuai §2.3: `onCreateWindow` → `return false` + log. Jangan buat WebView baru.
- [ ] Pasang hook di `browser_controller.dart`: `useShouldInterceptRequest: true`, `useShouldOverrideUrlLoading: true`.

### Data & UI

- [ ] `block_log.dart`: ring buffer 500 entri (`BlockLogEntry {host, url, reason, rule, time, kind}`) + `ValueNotifier`/Stream.
- [ ] `block_log_sheet.dart`: bottom sheet berisi daftar blokir, dikelompokkan per host, jumlah blokir, tombol **Allow** per host, tombol bersihkan log.
- [ ] Tombol menu di `BrowserPage` → buka log sheet (sementara; pindah ke Settings di M4).
- [ ] `hosts.txt` diisi Peter Lowe's list (~3.500 host) + tambahan manual: `exoclick.com`, `popads.net`, `propellerads.com`, `onclickads.net`, `popcash.net`, `adsterra.com`, `hilltopads.net`, `juicyads.com`. Tanpa komentar panjang; format `docs/RULES-FORMAT.md`.

### Test

- [ ] `test/rule_engine_test.dart`: suffix match (positif/negatif), port, uppercase, media bypass menang atas blocklist, allowlist menang atas blocklist, skema diblokir, top-level tidak kena blocklist, fail-open saat data korup.
- [ ] Test performa ringan: 100.000 lookup < 200 ms di VM.

## Kriteria selesai

- [ ] Buka halaman Doodstream/Videy (device pemilik): video tetap main.
- [ ] Popup saat klik play tidak membuka tab/halaman baru.
- [ ] Klik area kosong tidak redirect ke domain iklan.
- [ ] Log menampilkan minimal satu host iklan yang diblokir.
- [ ] Tombol Allow membuat host itu lolos (verifikasi dari log: tidak muncul lagi).
- [ ] Request media (`.m3u8`/`.mp4`) tidak pernah muncul di log sebagai blocked.
- [ ] `flutter analyze` 0 issue, `flutter test` hijau.

## Verifikasi

```bash
flutter analyze && flutter test
flutter run -d <device>
```
Manual di device: buka 1 URL Doodstream + 1 URL Videy, mainkan video, buka log, tekan Allow pada satu host, mainkan ulang.

Bila situs tidak bisa diakses saat pengujian, catat di STATUS §5 sebagai "belum teruji di device" dan jangan tandai `DONE`.

## Di luar lingkup

- Cosmetic filter / overlay DOM (M3).
- Update rule pack remote (M4).
- Regex `globalUrlPatterns` dari `sites.json` — boleh disiapkan di engine (kosong), pengisian di M4.

## Catatan untuk sesi berikut

- `shouldInterceptRequest` berjalan di thread lain; jangan melakukan I/O atau `await` di dalamnya. Semua data harus sudah di memori.
- Jangan blokir `*.js` dari domain yang sama dengan halaman; banyak player (jwplayer, plyr) bergantung pada script inline.
- Jika video mati setelah M2, tersangka pertama: CDN atau `thirdPartyCookiesEnabled`. Perbaiki di allowlist, jangan matikan guard.
