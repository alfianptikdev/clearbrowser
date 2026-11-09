# STATUS — Clear Browser

**Berkas ini wajib di-update di akhir setiap sesi agent.** Ini satu-satunya sumber kebenaran tentang "sudah sampai mana".

Terakhir diperbarui: 2026-11-09 · Sesi: 0 (dokumentasi)

## 1. Papan milestone

| # | Milestone | Status | Sesi | Commit | Catatan |
|---|---|---|---|---|---|
| M1 | Browser shell + WebView tuning | `TODO` | — | — | Belum ada kode |
| M2 | Adblock jaringan + navigasi + popup + log | `TODO` | — | — | Butuh M1 |
| M3 | Cosmetic engine + site profile | `TODO` | — | — | Butuh M2 |
| M4 | Rule pack remote + settings + history/tab | `TODO` | — | — | Butuh M3 |
| M5 | Mode Video Bersih (native player) | `TODO` | — | — | Opsional, v1.1 |

Legenda: `TODO` · `IN_PROGRESS` · `BLOCKED` · `DONE`

## 2. Sesi berikutnya

**Kerjakan: M1.** Instruksi lengkap ada di `docs/milestones/M1-browser-shell.md`.

Kalau M1 sudah `DONE`, kerjakan milestone pertama yang masih `TODO` dan tidak `BLOCKED`.

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

## 5. Masalah yang diketahui

| # | Masalah | Status | Solusi sementara |
|---|---|---|---|
| — | Belum ada | — | — |

## 6. Catatan handoff terakhir

Belum ada sesi implementasi. Saat mulai M1:

1. Baca `docs/milestones/M1-browser-shell.md` sampai habis (satu file).
2. `flutter create --org com.alfianptik --project-name cleanbrowser --platforms=android .` (jalankan di root proyek, `docs/` tidak akan terhapus).
3. Set `android:label="Clear Browser"` pada `AndroidManifest.xml`.
4. Selesaikan kriteria selesai M1, lalu update tabel §1, §4, dan §6 di file ini.
