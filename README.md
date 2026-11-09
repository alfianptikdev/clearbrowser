# Clear Browser

Browser Android (Flutter) yang memblokir iklan popup, popunder, dan overlay di situs streaming video seperti Doodstream dan Videy.

- **Package**: `com.alfianptik.cleanbrowser`
- **Platform**: Android (minSdk 24)
- **Distribusi**: sideload APK
- **Status**: fase dokumentasi — belum ada kode aplikasi

## Struktur

```
AGENTS.md                  # protokol kerja agent (baca pertama kali)
docs/
  PRD.md                   # kebutuhan produk (FR/NFR, policy, metrik)
  ARCHITECTURE.md          # lapisan, alur request, struktur folder, storage
  RULES-FORMAT.md          # format hosts.txt / sites.json / version.json
  STATUS.md                # papan status + log sesi + handoff
  milestones/
    M1-browser-shell.md
    M2-network-adblock.md
    M3-cosmetic-engine.md
    M4-rulepack-ux.md
    M5-native-player.md
```

## Mulai kerja

1. Buka `docs/STATUS.md`, lihat milestone yang `TODO`.
2. Buka file milestone itu, kerjakan dari atas ke bawah.
3. Update `docs/STATUS.md` di akhir sesi.

Milestone pertama: **M1** — `docs/milestones/M1-browser-shell.md`.

## Empat lapis pemblokiran

| Lapis | Menangani | Milestone |
|---|---|---|
| Request | iframe/script/gambar dari host iklan | M2 |
| Navigasi | redirect paksa, `intent://`, `market://` | M2 |
| Popup | `window.open`, `target=_blank` | M2 |
| Cosmetic | overlay DOM yang menutupi video | M3 |

Rule pack (`hosts.txt`, `sites.json`) bisa di-update tanpa rilis ulang APK (M4). Mode Video Bersih (native player) adalah rencana cadangan v1.1 (M5).
