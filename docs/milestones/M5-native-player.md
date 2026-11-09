# M5 — Mode Video Bersih (Native Player)

| | |
|---|---|
| Status | `TODO` |
| Depends on | M2 (sniffer), M4 (rilis v1.0 stabil) |
| Blocks | — |
| Estimasi | 1–2 sesi |
| Prioritas | Opsional, v1.1 — **kerjakan hanya jika M1–M4 masih menyisakan iklan/HLS rusak** |

## Tujuan

Untuk situs yang masih membandel atau yang HLS-nya tidak jalan di Android WebView: ekstrak URL media dari request yang sudah lolos, lalu putar di native player. Hasilnya nol iklan secara konstruksi (halaman tidak dirender) dan pemutaran HLS/mp4 yang andal.

## Prasyarat

- M4 `DONE`, v1.0 stabil dan teruji di device pemilik.
- Ada bukti masalah nyata yang M1–M4 tidak selesaikan (catat di STATUS §5).

## Task

- [ ] Tambah dependency: `media_kit`, `media_kit_video`, `media_kit_libs_android_video`.
- [ ] `media_sniffer.dart`:
  - [ ] Dengarkan `shouldInterceptRequest` (non-main-frame) dan `onLoadResource`.
  - [ ] Kandidat: ekstensi `.m3u8`/`.mp4` **atau** `content-type` `application/vnd.apple.mpegurl`/`video/mp4`.
  - [ ] Simpan maks 20 URL unik per tab dengan `{url, contentType, headers (Referer/User-Agent), waktu}`.
  - [ ] **Jangan** mengunduh; hanya mencatat.
- [ ] UI: tombol **Putar bersih** di address bar muncul bila ada kandidat; badge jumlah kandidat; long-press → pilih kandidat.
- [ ] `player_page.dart`:
  - [ ] `Player` + `VideoController` dari media_kit; kirim header Referer/UA dari sniffer (banyak CDN menolak tanpa Referer).
  - [ ] Kontrol: play/pause, seek bar, durasi, volume, fullscreen, kecepatan 0.5×–2×.
  - [ ] Gesture: horizontal = seek, vertikal kiri = brightness, vertikal kanan = volume.
  - [ ] Simpan posisi terakhir per URL (opsional, `settings.videoPositions`).
  - [ ] Orientasi landscape saat fullscreen; `SystemChrome` immersive.
- [ ] Fallback: bila player gagal (`error` stream), tampilkan pesan + tombol "Kembali ke browser".
- [ ] Jangan hapus WebView: tombol back kembali ke halaman asal, state tab tetap.

## Kriteria selesai

- [ ] URL Doodstream yang sebelumnya rusak di WebView bisa diputar native, termasuk seek dan fullscreen.
- [ ] Videy (mp4) terputar native.
- [ ] Header Referer terkirim (verifikasi: video tidak 403).
- [ ] Tidak ada iklan/overlay/popup sama sekali selama memutar (halaman tidak dimuat).
- [ ] Kembali dari player tidak merusak tab asal.
- [ ] `flutter analyze` 0 issue, `flutter test` hijau (test sniffer: deteksi ekstensi, dedupe, batas 20).

## Verifikasi

```bash
flutter analyze && flutter test
flutter run -d <device>
```
Manual: buka URL target → tunggu 2–3 detik → tombol Putar bersih → uji seek/fullscreen → back.

## Di luar lingkup

- Unduh video ke penyimpanan.
- Ekstraksi dari situs ber-DRM.
- Dukungan subtitle eksternal otomatis (boleh manual).

## Catatan untuk sesi berikut

- URL media sering kedaluwarsa (token di query). Simpan hanya selama sesi tab; jangan cache lintas sesi.
- Jika sniffer tidak menemukan apa pun, kemungkinan player memakai `blob:`/MSE — kasus ini tidak bisa di-extract; laporkan sebagai batasan, jangan dipaksa.
