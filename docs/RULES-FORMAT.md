# Format Rule Pack

Rule pack terdiri dari tiga file di `assets/rules/` dan bisa diganti versi remote dengan struktur identik. **Tidak ada selector/host yang boleh ditulis di kode Dart.**

## 1. `hosts.txt`

Satu host per baris. Komentar diawali `#`. Baris kosong diabaikan. Tanpa `0.0.0.0`, tanpa wildcard.

```
# Clear Browser hosts (format: satu host per baris)
doubleclick.net
googlesyndication.com
exoclick.com
popads.net
propellerads.com
onclickads.net
...
```

Pencocokan: **suffix per label**. `ads.doubleclick.net` cocok dengan `doubleclick.net`; `notdoubleclick.net` **tidak** cocok. Maksimum 4 iterasi label per lookup.

Aturan authoring:
- Domain induk saja (`exoclick.com`, bukan `cdn1.exoclick.com`).
- Jangan masukkan host CDN video atau player (`jwplayer.com`, `plyr.io`, `*.googlevideo.com`, dsb).
- Maksimum ~150.000 baris (batas praktis performa). Target v1: ~3.500–10.000.

## 2. `sites.json`

```json
{
  "version": 3,
  "updatedAt": "2026-11-09",
  "globalUrlPatterns": [
    "^https?://[^/]*(exoclick|popads|propellerads|onclickads)\\.",
    "[/?&](utm_source=ad|aff_id=|clickid=)"
  ],
  "blockTopLevel": [
    "exoclick.com",
    "popads.net"
  ],
  "sites": {
    "doodstream.com": {
      "enabled": true,
      "stealth": true,
      "selectors": [
        "div[class*='overlay-ad']",
        "#ad-overlay",
        "div[id^='ad_layer']"
      ],
      "closeSelectors": [
        ".close-ad",
        "button[aria-label*='lose' i]",
        "span.close"
      ],
      "extraUrlPatterns": ["/e/[a-z0-9]+\\?.*(ad|pop)="],
      "allowHosts": [],
      "note": "Popup muncul saat klik area player; overlay fullscreen saat pause."
    },
    "videy.co": {
      "enabled": true,
      "stealth": false,
      "selectors": ["iframe[src*='ads']", ".ad-banner"],
      "closeSelectors": [],
      "extraUrlPatterns": [],
      "allowHosts": [],
      "note": "Iklan berupa banner di sekitar player, bukan overlay."
    }
  }
}
```

### Skema field

| Field | Tipe | Wajib | Arti |
|---|---|---|---|
| `version` | int | ya | Naikkan setiap perubahan isi |
| `updatedAt` | string | ya | `YYYY-MM-DD` |
| `globalUrlPatterns` | string[] | tidak | Regex URL iklan yang berlaku semua situs |
| `blockTopLevel` | string[] | tidak | Host yang juga diblokir untuk navigasi top-level |
| `sites` | object | ya | Key = domain, berlaku untuk domain + subdomain |
| `sites.*.enabled` | bool | ya | Toggle default situs |
| `sites.*.stealth` | bool | tidak | Aktifkan penyanaran tambahan (default `false`) |
| `sites.*.selectors` | string[] | tidak | CSS selector overlay yang dihapus paksa |
| `sites.*.closeSelectors` | string[] | tidak | Selector tombol close untuk diklik otomatis |
| `sites.*.extraUrlPatterns` | string[] | tidak | Regex tambahan untuk `RequestGuard` |
| `sites.*.allowHosts` | string[] | tidak | Host yang selalu lolos bila profil ini aktif |
| `sites.*.note` | string | tidak | Catatan pemeliharaan |

Aturan authoring:
- Regex harus **case-insensitive**, tanpa lookbehind (tidak didukung di semua WebView).
- Selector harus spesifik; `.ad` terlalu umum dan dilarang.
- Setiap situs baru wajib punya `note` berisi gejala yang terlihat di perangkat.

## 3. `version.json`

```json
{
  "version": 3,
  "updatedAt": "2026-11-09",
  "hostsUrl": "https://raw.githubusercontent.com/<user>/<repo>/main/rules/hosts.txt",
  "sitesUrl": "https://raw.githubusercontent.com/<user>/<repo>/main/rules/sites.json"
}
```

`hostsUrl`/`sitesUrl` boleh kosong pada versi asset; `RulePackLoader` memakai URL dari `core/constants.dart` bila field kosong.

## 4. Prosedur update tanpa rilis APK

1. Ubah `hosts.txt` / `sites.json` di repo rule.
2. Naikkan `version` dan `updatedAt`.
3. Push ke branch `main`.
4. Di aplikasi: Settings → **Update rule pack**.
5. Verifikasi: Settings menampilkan versi baru; Settings → Log blokir menampilkan rule yang aktif.
6. Jika situs jadi rusak: jangan turunkan versi global — tambahkan entry `allowHosts` atau set `enabled: false` untuk domain itu, naikkan versi.

## 5. Checklist sebelum menambah rule

- [ ] Host bukan CDN video/player.
- [ ] Regex diuji di halaman asli (tidak false positive ke media).
- [ ] Selector diuji di halaman asli (overlay hilang, player tetap utuh).
- [ ] `version` dinaikkan.
- [ ] `note` diisi bila menyangkut situs tertentu.
