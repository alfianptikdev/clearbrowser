# M4 — Rule Pack Remote + Settings + History/Tab

| | |
|---|---|
| Status | `TODO` |
| Depends on | M3 |
| Blocks | M5 (tidak wajib), rilis v1.0 |
| Estimasi | 1–2 sesi |
| File milik | `lib/adblock/rule_pack_loader.dart`, `lib/data/*`, `lib/ui/settings_page.dart`, `lib/browser/tab_manager.dart`, `tab_view_stack.dart`, `assets/rules/version.json`, `test/rule_pack_loader_test.dart` |

## Tujuan

Aplikasi bisa diperbaiki tanpa rilis ulang APK (update rule pack), pengguna punya kendali (toggle global/per-situs/allowlist), dan browser terasa lengkap (history, bookmark, multi-tab).

## Prasyarat

- M3 `DONE`: `hosts.txt` + `sites.json` + `RuleEngine`/`SiteProfiles` sudah dimuat dari asset.

## Task

### Rule pack

- [ ] `assets/rules/version.json` sesuai `docs/RULES-FORMAT.md` §3.
- [ ] `rule_pack_loader.dart`:
  - [ ] `load()` urutan prioritas: cache di `path_provider` → asset bawaan.
  - [ ] `update()`: `GET` `hostsUrl` & `sitesUrl` dengan timeout 10 s, `If-None-Match`/ETag bila ada.
  - [ ] Validasi sebelum simpan: hosts minimal 100 baris & semua baris cocok `^[a-z0-9.-]+$`; sites harus `jsonDecode` dan punya `version`.
  - [ ] Tulis atomik (tulis `.tmp` lalu rename); jangan pernah menimpa cache dengan data invalid.
  - [ ] Simpan `rules.version` = `"<version> · <updatedAt>"`.
  - [ ] Gagal total → tetap pakai data lama, kembalikan `UpdateResult.failure(reason)`.
- [ ] `RuleEngine.reload()` dan `SiteProfiles.reload()` agar update berlaku tanpa restart.
- [ ] Unit test loader: valid, invalid JSON, hosts korup, offline (mock client gagal).

### Settings

- [ ] `settings_page.dart`:
  - [ ] Toggle **Blokir iklan** (global, langsung berlaku).
  - [ ] Status rule pack: versi, tanggal, tombol **Update sekarang**, spinner + hasil (sukses/gagal + alasan).
  - [ ] Daftar allowlist: hapus per host.
  - [ ] Toggle per-situs dari `sites.json` (switch), disimpan di `settings.siteOverrides`.
  - [ ] "Bersihkan log blokir", "Bersihkan history".
  - [ ] Info app: versi, package, tautan aturan format rule.
- [ ] Tombol menu di `BrowserPage` → Settings (ganti tombol log sementara dari M2; log tetap bisa dibuka dari Settings).

### History, bookmark, tab

- [ ] `history_store.dart`: maks 500, dedupe URL berurutan, timestamps, hapus semua.
- [ ] `bookmark_store.dart`: tambah/hapus dari menu, daftar di Settings.
- [ ] `tab_manager.dart`: daftar `Tab {id, url, title, webViewController}`, batas 10 tab (LRU dispose), tab aktif.
- [ ] `tab_view_stack.dart`: `IndexedStack` agar WebView tidak reload saat pindah tab.
- [ ] Tab strip UI: judul pendek + tombol close + tombol new tab; state tab terakhir dipersist (URL saja, opsional).
- [ ] Simpan history hanya saat `onLoadStop` dan URL bukan `about:blank`.

## Kriteria selesai

- [ ] Update rule pack mengubah versi di Settings **tanpa** restart app.
- [ ] Mode pesawat → Update gagal dengan pesan jelas; aplikasi tetap berfungsi dengan cache.
- [ ] Rule pack invalid dari remote ditolak; versi lama tetap aktif.
- [ ] Toggle global off → iklan kembali muncul (uji di harness M3).
- [ ] Allow/unallow dari Settings memengaruhi perilaku segera.
- [ ] 3 tab terbuka; pindah tab tidak memuat ulang halaman dan posisi scroll dipertahankan.
- [ ] History menampilkan kunjungan, maksimal 500 entri, bisa dihapus.
- [ ] `flutter analyze` 0 issue, `flutter test` hijau.

## Verifikasi

```bash
flutter analyze && flutter test
flutter run -d <device>
```
Manual: Settings → Update (bandingkan versi), mode pesawat → Update, buka 3 tab, cek history.

## Di luar lingkup

- Sinkronisasi bookmark/history ke cloud.
- Mode incognito (FR-15, `Could`).
- Unduhan file.
- Auto-update rule pack berkala di background (v1: manual saja).

## Catatan untuk sesi berikut

- Jangan auto-update di startup tanpa izin: satu-satunya koneksi keluar harus dipicu pengguna (kecuali diputuskan lain dan dicatat di STATUS).
- URL rule pack untuk v1 boleh menunjuk repo GitHub pemilik; kalau belum ada, isi string kosong dan sembunyikan tombol Update dengan pesan "URL rule pack belum dikonfigurasi".
- Tab + IndexedStack menaikkan memori; uji 3 tab video 1080p terhadap NFR-03 (< 400 MB).
