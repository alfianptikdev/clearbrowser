# AGENTS.md — Clear Browser

Browser Android berbasis Flutter yang memblokir iklan popup/overlay di situs streaming (Doodstream, Videy, sejenis).
Flutter 3.35.3 · Dart 3.9.2 · Java 21 · minSdk 24 · package `com.alfianptik.cleanbrowser`.

---

## 1. Protokol sesi (WAJIB, urutan ini)

1. Baca `docs/STATUS.md` — cari milestone `TODO`/`IN_PROGRESS` pertama. **Hanya itu yang dikerjakan.**
2. Baca **satu** file: `docs/milestones/Mx-*.md`.
3. Baca `docs/PRD.md` **hanya §6–§8** (kebutuhan + policy) bila perlu. Jangan baca seluruh PRD.
4. Baca `docs/ARCHITECTURE.md` **hanya** bagian yang disentuh (alur request / struktur / format rule).
5. Kerjakan → verifikasi → update `docs/STATUS.md` → tulis handoff.

Jangan memuat semua dokumen sekaligus. Jangan mengerjakan dua milestone dalam satu sesi.

## 2. Aturan keras (jangan dilanggar)

1. **Media selalu lolos.** Ekstensi di `core/constants.dart` (`.m3u8 .ts .mp4 .m4s .vtt .key`) dan host CDN video tidak boleh diblokir. Dievaluasi sebelum blocklist.
2. **Fail-open.** Error/timeout di rule engine → request diloloskan. Jangan pernah fail-closed.
3. **Nol hardcode situs.** Selector/host/regex hanya di `assets/rules/*`. Dart hanya membaca model.
4. **Nol telemetry.** Tidak ada analytics, crash reporting pihak ketiga, atau unggah URL. Satu-satunya jaringan keluar: unduh rule pack.
5. **Jangan tambah permission Android** tanpa memperbarui PRD §7 dan STATUS D-log.
6. **Jangan upgrade** Flutter/AGP/Gradle major di tengah milestone.
7. **Satu milestone = satu commit** (boleh beberapa commit kecil, tapi jangan campur dua milestone).
8. `flutter analyze` harus 0 issue dan `flutter test` harus hijau sebelum menandai `DONE`.
9. **Update `docs/STATUS.md` wajib.** Sesi tanpa update status = sesi gagal.
10. Uji di perangkat fisik hanya bisa dilakukan pemilik. Jangan mengklaim situs sungguhan sudah teruji bila belum.

## 3. Kepemilikan file per milestone

Hindari mengedit file milik milestone lain. Bila perlu, ubah seminimal mungkin dan catat di handoff.

| Milestone | File utama |
|---|---|
| M1 | `pubspec.yaml`, `lib/main.dart`, `lib/app.dart`, `lib/core/*`, `lib/browser/browser_page.dart`, `webview_setup.dart`, `address_bar.dart`, `android/**`, `test/widget_test.dart` |
| M2 | `lib/adblock/rule_engine.dart`, `request_guard.dart`, `navigation_guard.dart`, `popup_guard.dart`, `block_log.dart`, `assets/rules/hosts.txt`, `lib/ui/block_log_sheet.dart`, `test/rule_engine_test.dart` |
| M3 | `lib/adblock/cosmetic_script.dart`, `site_profiles.dart`, `assets/rules/sites.json`, `test/fixtures/**`, `test/site_profiles_test.dart` |
| M4 | `lib/adblock/rule_pack_loader.dart`, `lib/data/*`, `lib/ui/settings_page.dart`, `lib/browser/tab_manager.dart`, `tab_view_stack.dart`, `assets/rules/version.json` |
| M5 | `lib/media/*`, `pubspec.yaml` (tambah media_kit) |

`lib/browser/browser_controller.dart` disentuh M1 lalu boleh ditambah hook oleh M2/M3 (satu baris per guard), catat di handoff.

## 4. Peta dokumen

| Dokumen | Baca kapan |
|---|---|
| `docs/STATUS.md` | **Setiap sesi, pertama** |
| `docs/milestones/Mx-*.md` | Satu file per sesi |
| `docs/PRD.md` | §6–§8 saat butuh daftar kebutuhan/policy |
| `docs/ARCHITECTURE.md` | Saat menyentuh alur request, settings, storage |
| `docs/RULES-FORMAT.md` | Saat mengubah `hosts.txt` / `sites.json` |
| `docs/PRD.md` §11 | Saat bingung urutan milestone |

## 5. Perintah

```bash
flutter pub get
flutter analyze          # wajib 0 issue
flutter test             # wajib hijau
flutter run -d <device>  # perangkat fisik pemilik
flutter build apk --release --split-per-abi

# debug WebView (device tersambung)
adb logcat | grep -iE "chromium|cleanbrowser|flutter"
# lalu buka chrome://inspect di Chrome desktop
```

Scope M1: `flutter create --org com.alfianptik --project-name cleanbrowser --platforms=android .`

## 6. Definition of Done (berlaku semua milestone)

- [ ] Semua kotak `Task` di file milestone tercentang.
- [ ] Semua `Kriteria selesai` terbukti (test otomatis atau langkah manual yang dicatat).
- [ ] `flutter analyze` 0 issue, `flutter test` hijau.
- [ ] Tidak ada TODO/FIXME menggantung tanpa catatan di STATUS.
- [ ] `docs/STATUS.md` §1 (status + commit), §4 (log sesi), §5 (masalah) diperbarui.
- [ ] Handoff ditulis di `docs/STATUS.md` §6.

## 7. Template handoff (tulis di STATUS §6)

```md
### Sesi N — Mx selesai
- Yang dibuat: <file/fitur>
- Verifikasi: analyze 0 issue · test <n> lulus · manual: <langkah>
- Belum teruji: <hal yang butuh device/pemilik>
- Catatan untuk sesi berikut: <jebakan, keputusan kecil, hal yang perlu diperbaiki>
- Commit: <hash> <pesan>
```

## 8. Gaya kode

- Dart: `dart format`, nama Inggris, komentar Indonesia hanya untuk keputusan non-obvious.
- Satu kelas satu tanggung jawab; guard menerima URL/request, mengembalikan keputusan + alasan (bukan void), agar bisa di-log dan di-unit-test.
- Semua keputusan blokir mengembalikan objek `BlockDecision {blocked, reason, rule}`.
- Tidak ada `print` di release; pakai `core/logger.dart` yang no-op di release.
