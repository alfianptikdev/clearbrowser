/// Nilai global yang dipakai lintas lapisan.
///
/// Aturan (lihat `docs/ARCHITECTURE.md` §4): jangan menduplikasi daftar di sini
/// ke guard/page. Semua guard membaca dari file ini.
library;

class AppInfo {
  AppInfo._();

  static const String name = 'Clear Browser';
  static const String packageId = 'com.alfianptik.cleanbrowser';
  static const String version = '1.0.0';
}

class StorageKeys {
  StorageKeys._();

  static const String adblockEnabled = 'settings.adblockEnabled';
  static const String allowlist = 'settings.allowlist';
  static const String learnedHosts = 'rules.learnedHosts';
  static const String pinnedSites = 'settings.pinnedSites';
  static const String siteOverrides = 'settings.siteOverrides';
  static const String rulesHosts = 'rules.hosts';
  static const String rulesSites = 'rules.sites';
  static const String rulesVersion = 'rules.version';
  static const String history = 'history.v1';
  static const String bookmarks = 'bookmarks.v1';
  static const String tabs = 'tabs.v1';
}

/// UA Chrome Android asli. Jangan pakai UA default WebView ("; wv") agar situs
/// tidak mendeteksi kita sebagai WebView dan menolak memutar video.
const String kDefaultUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

const String kHomeUrl = 'https://duckduckgo.com';
const String kSearchUrl = 'https://duckduckgo.com/?q=';

/// FR-16 / aturan keras #1: request dengan ekstensi ini tidak boleh diblokir.
const List<String> kMediaExtensions = <String>[
  '.m3u8',
  '.m3u',
  '.mpd',
  '.ts',
  '.m4s',
  '.mp4',
  '.m4a',
  '.webm',
  '.vtt',
  '.key',
];

/// Host CDN video yang selalu diloloskan (FR-16).
const List<String> kMediaCdnHosts = <String>[
  'googlevideo.com',
  'cloudflarestream.com',
  'videy.co',
  'b-cdn.net',
  'bunnycdn.com',
  'mux.com',
  'akamaized.net',
  'cloudfront.net',
  'fastly.net',
];

const int kMaxBlockLogEntries = 500;
const int kMaxHistoryEntries = 500;
const int kMaxTabs = 10;
