# M3 — Cosmetic Engine + Site Profile

| | |
|---|---|
| Status | `TODO` |
| Depends on | M2 (`RuleEngine`, `BlockLog`, allowlist) |
| Blocks | M4 (butuh `sites.json` untuk rule pack) |
| Estimasi | 1–2 sesi |
| File milik | `lib/adblock/cosmetic_script.dart`, `site_profiles.dart`, `assets/rules/sites.json`, `test/site_profiles_test.dart`, `test/fixtures/**`, `lib/ui/cosmetic_test_page.dart` |

## Tujuan

Menghapus iklan yang sudah terlanjur dirender di DOM: overlay fullscreen, banner, tombol close palsu — plus mencegah redirect yang dipicu klik. Ini lapisan yang paling terasa di Doodstream/Videy, karena popup blocker saja tidak menghilangkan `div` yang menutupi video.

## Prasyarat

- M2 `DONE`. Log blokir bisa dipakai memverifikasi bahwa script kosmetik tidak ikut memblokir resource sah.

## Task

### Model & data

- [ ] `site_profiles.dart`: model `SiteProfile {domain, enabled, stealth, selectors[], closeSelectors[], extraUrlPatterns[], allowHosts[], note}`.
- [ ] `SiteProfiles.fromJson()` tahan error: field hilang → default; JSON rusak → `{}` + log.
- [ ] `profileFor(String host)`: cocokkan domain + subdomain (`www.` diabaikan), pilih yang paling spesifik.
- [ ] Isi `assets/rules/sites.json` sesuai skema `docs/RULES-FORMAT.md` untuk: `doodstream.com`, `dood.li`, `videy.co`, `fembed.com`, `streamtape.com` (best-effort, wajib ada `note`).
- [ ] `enabled`/`stealth` per-situs dapat ditimpa toggle pengguna (disimpan di prefs, UI di M4).

### Skrip kosmetik

- [ ] `cosmetic_script.dart`: `build(SiteProfile?, {bool stealth})` → string JS.
- [ ] Bungkus dalam IIFE; **tidak ada** variabel/`data-*` global yang mudah dideteksi.
- [ ] Override `window.open` → `null`; `window.onbeforeunload` → `null`; blokir `alert` berulang (maks 1 per halaman).
- [ ] Click guard capture-phase:
  - [ ] `event.isTrusted === false` → `preventDefault`.
  - [ ] `a[target=_blank]` cross-origin → `preventDefault`.
  - [ ] klik dengan `href` berskema `intent|market|tel|sms` → `preventDefault`.
- [ ] Sweep overlay generic dengan skoring (§2.4 ARCHITECTURE):
  - [ ] kandidat: `position fixed|absolute`, `z-index ≥ 1000`, luas ≥ 25% viewport.
  - [ ] harus mengandung `iframe` atau `a` eksternal atau `img` besar.
  - [ ] **exclude** elemen yang merupakan ancestor/descendant dari `video`, `.jwplayer`, `.plyr`, `[class*=player]`.
  - [ ] skor ≥ 3 → `display:none !important` (set via `style.setProperty` dengan `important`).
- [ ] Selector eksplisit dari profil → langsung sembunyikan pada sweep pertama.
- [ ] Auto-klik tombol close asli: `closeSelectors` + teks `× ✕ close skip tutup lewati` (maks 1 klik per elemen, jangan klik tombol yang membuka link eksternal).
- [ ] MutationObserver (debounce 300 ms) + sweep pada `DOMContentLoaded`, `load`, dan `+1500 ms`.
- [ ] `stealth: true` → tambahan: patch `MutationObserver` detection? **Jangan**. Cukup: tidak memasang atribut global, dan menunda override sampai microtask pertama.
- [ ] Inject via `UserScript(injectionTime: AT_DOCUMENT_START, forMainFrameOnly: false)`; rebuild saat profil situs berubah (`onLoadStart` → pilih profil untuk host).

### Test

- [ ] `test/site_profiles_test.dart`: parse valid, field hilang, JSON rusak, subdomain match, `www` stripping.
- [ ] Test builder: output mengandung selector profil, tidak mengandung nama variabel global.
- [ ] `lib/ui/cosmetic_test_page.dart` (**harness offline, penting**): halaman yang memuat `initialData` HTML dengan 4 kasus:
  1. overlay `fixed z-index:9999` menutupi 100% viewport,
  2. tombol "close" palsu yang memanggil `window.open`,
  3. link `target=_blank` eksternal,
  4. tombol redirect `location.href` ke domain lain.
  Harness hanya di mode debug; tidak muncul di rilis.

## Kriteria selesai

- [ ] Harness offline: overlay hilang < 1 detik, tidak ada popup, klik palsu tidak redirect.
- [ ] Video di halaman harness tetap terlihat (tidak ikut ter-hide).
- [ ] Doodstream/Videy (device): overlay hilang, video tetap main, player tetap bisa di-pause/seek.
- [ ] Selector situs berubah hanya dengan mengedit `sites.json` (rebuild asset), tanpa mengubah Dart.
- [ ] `flutter analyze` 0 issue, `flutter test` hijau.

## Verifikasi

```bash
flutter analyze && flutter test
flutter run -d <device>
```
Buka harness lewat menu debug → pastikan 4 kasus lolos → baru uji situs asli.

## Di luar lingkup

- Remote update `sites.json` (M4).
- Deteksi overlay berbasis screenshot/ML (tidak akan dilakukan).
- Native player (M5).

## Catatan untuk sesi berikut

- Skoring adalah heuristik: utamakan **tidak** menghapus apa pun daripada menghapus player. Kalau ragu, turunkan skor dan andalkan selector eksplisit per-situs.
- Jangan pakai selector umum seperti `.ad`, `div[id*=ad]` — mematikan player Doodstream yang memakai id serupa. Wajib spesifik.
- Bila situs memblokir karena mendeteksi injection, set `stealth: true` dan uji ulang; jangan menambah trik global yang bisa dideteksi.
