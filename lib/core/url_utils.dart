import 'constants.dart';

final RegExp _schemePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):(.*)$');
final RegExp _portPattern = RegExp(r'^\d{1,5}(?:[/?#].*)?$');
final RegExp _whitespacePattern = RegExp(r'\s');
final RegExp _hostPattern = RegExp(
  r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}'
  r'(?::\d{1,5})?(?:[/?#].*)?$',
);
final RegExp _localhostPattern = RegExp(
  r'^localhost(?::\d{1,5})?(?:[/?#].*)?$',
  caseSensitive: false,
);
final RegExp _ipv4Pattern = RegExp(
  r'^(?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?(?:[/?#].*)?$',
);

String toSearchUrl(String query) =>
    '$kSearchUrl${Uri.encodeQueryComponent(query)}';

/// FR-02: mengubah input address bar menjadi URL siap muat.
///
/// - kosong → halaman awal
/// - sudah punya skema → dibiarkan (guard M2 yang memutuskan boleh/tidak)
/// - mengandung spasi atau bukan domain → pencarian
/// - domain / IP / localhost → diberi awalan `https://`
String normalizeInput(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return kHomeUrl;

  final lower = input.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return input;
  }

  // Skema lain (intent:, market:, tel:, ...) dibiarkan apa adanya agar
  // NavigationGuard (M2) bisa memblokirnya dengan alasan yang jelas.
  //
  // Hati-hati: "localhost:8080" dan "example.com:8080" juga cocok dengan pola
  // skema. Skema sungguhan tidak mengandung titik, dan sisa setelah titik dua
  // bukan sekadar port.
  final schemeMatch = _schemePattern.firstMatch(input);
  if (schemeMatch != null) {
    final scheme = schemeMatch.group(1)!;
    final rest = schemeMatch.group(2)!;
    final isScheme = !scheme.contains('.') && !_portPattern.hasMatch(rest);
    if (isScheme) return input;
  }

  if (_whitespacePattern.hasMatch(input)) return toSearchUrl(input);

  if (_hostPattern.hasMatch(input) ||
      _localhostPattern.hasMatch(input) ||
      _ipv4Pattern.hasMatch(input)) {
    return 'https://$input';
  }

  return toSearchUrl(input);
}

String hostOf(String url) => Uri.tryParse(url)?.host.toLowerCase() ?? '';

bool isSecureUrl(String url) => url.toLowerCase().startsWith('https://');
