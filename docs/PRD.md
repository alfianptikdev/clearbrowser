# PRD — Clear Browser

| Field | Isi |
|---|---|
| Nama produk | Clear Browser |
| Package ID | `com.alfianptik.cleanbrowser` |
| Platform | Android (minSdk 24, target SDK terbaru) |
| Versi dokumen | 1.0 |
| Status | Disetujui untuk M1 |
| Pemilik | Alfian (pengguna tunggal, sideload APK) |

---

## 1. Ringkasan

Clear Browser adalah browser Android berbasis Flutter yang dirancang untuk satu masalah spesifik: **iklan popup, popunder, dan overlay di situs streaming video** seperti Doodstream, Videy, Fembed, dan sejenisnya. Browser biasa gagal di situs-situs ini karena iklan dipicu oleh skrip halaman (bukan banner), sering menyamar sebagai tombol close, dan kadang memaksa keluar ke Play Store atau situs judi.

Clear Browser memblokir iklan itu di empat lapis (request, navigasi, cosmetic, popup) sehingga video tetap bisa ditonton tanpa gangguan, dan menyediakan jalur "Allow" per-domain agar situs yang rusak bisa dipulihkan tanpa menunggu rilis aplikasi baru.

## 2. Masalah

Saat membuka halaman video di situs tersebut, pengguna mengalami:

| # | Gejala | Penyebab teknis |
|---|---|---|
| P1 | Klik play → tab baru / halaman iklan terbuka | `window.open()` di handler klik player |
| P2 | Div besar menutupi video, tombol close malah membuka iklan | Overlay `position:fixed; z-index:9999` berisi iframe iklan |
| P3 | Klik di area kosong → redirect ke domain lain | Handler `click` global + `location.href` |
| P4 | Keluar ke Play Store / app lain | Skema `intent://`, `market://` |
| P5 | Video tidak mau jalan setelah blokir | Situs mendeteksi adblock (anti-adblock) atau CDN video ikut terblokir |

Kebutuhan nyata: **menonton tanpa interupsi, tanpa keluar aplikasi, tanpa mengorbankan pemutaran video.**

## 3. Tujuan

- **G1** Video di situs target dapat diputar tanpa popup/overlay mengganggu.
- **G2** Tidak ada navigasi keluar aplikasi yang tidak diminta pengguna.
- **G3** Pemblokiran tidak merusak pemutaran video (fail-open untuk media).
- **G4** Rule pemblokiran bisa diperbarui tanpa merilis ulang APK.
- **G5** Pengguna bisa memulihkan situs yang rusak dalam ≤ 2 tap (Allow dari log).
- **G6** Aplikasi tetap ringan: buka halaman < 3 detik di perangkat mid-range, tanpa penurunan FPS saat scroll.

## 4. Non-tujuan (v1.0)

- Bukan browser lengkap: tanpa sinkronisasi cloud, ekstensi, mode desktop penuh.
- Tidak mendukung iOS/macOS/Windows.
- Tidak mengunduh video massal / tidak melewati DRM.
- Tidak berisi SDK iklan, analytics, atau pelacakan apa pun.
- Tidak menjamin memblokir 100% iklan; target adalah situs target utama.

## 5. Pengguna & konteks pakai

- Satu pengguna (pemilik perangkat), instalasi via APK sideload.
- Skenario utama: malam hari, buka link video dari chat/sosial media, tempel ke address bar, tonton fullscreen, tutup.
- Skenario sekunder: baca artikel/blog, cari sesuatu lewat search engine.

## 6. Kebutuhan fungsional

Prioritas: **M** = Must (v1.0), **S** = Should, **C** = Could, **V1.1** = ditunda.

| ID | Kebutuhan | Prioritas | Milestone |
|---|---|---|---|
| FR-01 | Buka URL, address bar, tombol back/forward/reload, progress bar | M | M1 |
| FR-02 | Normalisasi input: tanpa skema → `https://`; bukan domain → pencarian | M | M1 |
| FR-03 | Pemutaran video inline dan fullscreen native, autoplay tanpa gesture | M | M1 |
| FR-04 | Blokir request ke host iklan (level jaringan) | M | M2 |
| FR-05 | Blokir popup window (`window.open`, `target=_blank`) | M | M2 |
| FR-06 | Blokir/bersihkan overlay iklan (cosmetic filter) | M | M3 |
| FR-07 | Blokir redirect paksa dan skema berbahaya (`intent://`, `market://`, `tel:`, `sms:`, `itms-apps://`) | M | M2 |
| FR-08 | Allowlist per-domain + tombol Allow dari log | M | M2 |
| FR-09 | Log blokir (domain, jenis rule, waktu), bisa dibuka dari menu | M | M2 |
| FR-10 | Site profile JSON per-situs: selector, pola URL, `stealth`, `enabled` | M | M3 |
| FR-11 | Rule pack dapat diperbarui dari remote, offline-first, fallback ke asset | M | M4 |
| FR-12 | Toggle global on/off + status rule pack (versi & tanggal) | M | M4 |
| FR-13 | History (maks 500) dan bookmark | S | M4 |
| FR-14 | Multi-tab, state WebView tidak reload saat pindah tab | S | M4 |
| FR-15 | Mode incognito (tanpa history/cookie persist) | C | — |
| FR-16 | Media always-allow: `*.m3u8`, `*.ts`, `*.mp4`, `*.m4s`, `*.vtt`, `*.key` tidak pernah diblokir | M | M2 |
| FR-17 | Mode Video Bersih: ekstrak URL media, putar di native player (HLS/mp4) | V1.1 | M5 |
| FR-18 | Pilih user-agent (mobile/desktop) | C | — |

## 7. Kebutuhan non-fungsional

| ID | Kebutuhan | Target |
|---|---|---|
| NFR-01 | Overhead `shouldInterceptRequest` | < 30 ms per request, tanpa jank saat scroll |
| NFR-02 | Waktu muat halaman normal (4G, mid-range) | < 3 detik |
| NFR-03 | Memori saat video 1080p | < 400 MB |
| NFR-04 | Privasi | Tanpa telemetry; history & log 100% lokal; hanya satu koneksi keluar (unduh rule pack, manual/startup) |
| NFR-05 | Ketahanan | Rule pack korup/gagal unduh → pakai asset bawaan, aplikasi tetap jalan |
| NFR-06 | Ukuran APK release (per ABI) | < 40 MB |
| NFR-07 | Maintainability | Selector situs 100% di `sites.json`, nol hardcode di Dart |
| NFR-08 | Kompatibilitas | Android 7.0–15 |

## 8. Aturan perilaku (policy)

1. **Fail-open.** Bila rule engine error/timeout, request diloloskan. Lebih baik iklan lolos daripada video mati.
2. **Media menang.** FR-16 dievaluasi sebelum blocklist. Tidak ada pengecualian.
3. **Allowlist menang.** Domain di allowlist pengguna selalu lolos, termasuk untuk popup.
4. **Top-level aman.** Navigasi halaman utama tidak pernah diblokir karena ada di blocklist host; hanya subresource yang diblokir. Pengecualian: host iklan murni yang memang tidak pernah jadi halaman (daftar terpisah `blockTopLevel`).
5. **Tanpa kejutan.** Setiap blokir tercatat di log; pengguna bisa melihat dan membatalkannya.
6. **Data pengguna tidak keluar perangkat.**

## 9. Metrik keberhasilan (definisi "berhasil")

| Uji | Target |
|---|---|
| Buka halaman video Doodstream, klik play | Video main; 0 tab/popup baru; tidak keluar app |
| Videy | Video main; overlay hilang < 1 detik |
| Klik area kosong di player | Tidak ada redirect |
| Log blokir | Menampilkan domain yang dicegat beserta jenis rule |
| Allow 1 domain dari log | Domain itu lolos, situs tetap jalan |
| Toggle global off | Perilaku kembali seperti WebView biasa |
| Scroll halaman berat | Tidak ada lag yang terasa |
| Update rule pack | Versi & tanggal berubah, tanpa rebuild APK |

## 10. Risiko & mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| False positive memblokir CDN video/player | Video mati | Media always-allow; allowlist; log |
| Situs mengubah DOM/selector | Overlay lolos | Selector di `sites.json` remote; generic scoring |
| Situs mendeteksi adblock | Video ditolak | Flag `stealth` per-situs; skrip tanpa global |
| HLS tidak didukung WebView Android | Video tidak jalan | M5 native player (media_kit) |
| Performa intercept di halaman berat | Lag | Early-out cepat, `Set` lookup, tanpa regex berat |
| Kebijakan store | Tidak bisa publikasi | Rilis sideload (keputusan D3) |

## 11. Roadmap

| Milestone | Lingkup | Status awal |
|---|---|---|
| M1 | Browser shell + WebView tuning | TODO |
| M2 | Adblock jaringan + navigasi + popup + log | TODO |
| M3 | Cosmetic engine + site profile | TODO |
| M4 | Rule pack remote + settings + history/tab | TODO |
| M5 | Mode Video Bersih (opsional, v1.1) | TODO |

Detail tiap milestone ada di `docs/milestones/`. Status terkini selalu di `docs/STATUS.md`.

## 12. Pertanyaan terbuka

1. Apakah perlu mode incognito di v1.0? (default: tidak)
2. Apakah perlu unduhan file (bukan video streaming)? (default: tidak)
3. Batas jumlah tab? (default: 10, LRU dispose)
