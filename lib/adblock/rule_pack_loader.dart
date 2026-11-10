import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/logger.dart';

/// Isi rule pack siap pakai.
class RulePack {
  const RulePack({
    required this.hosts,
    required this.sites,
    required this.versionLabel,
    required this.fromCache,
  });

  final String hosts;
  final String sites;

  /// `"<version> · <updatedAt>"` dari `sites.json`.
  final String versionLabel;
  final bool fromCache;
}

class UpdateResult {
  const UpdateResult.success(this.message, this.pack) : ok = true;
  const UpdateResult.failure(this.message) : ok = false, pack = null;

  final bool ok;
  final String message;
  final RulePack? pack;
}

/// Memuat rule pack: cache (`path_provider`) → asset bawaan. `update()` satu-
/// satunya jalur jaringan keluar app dan hanya dipicu pengguna.
///
/// shortcut: tanpa ETag/`If-None-Match` (selalu unduh penuh, ~100 KB); pasang
/// ETag bila ukuran rule pack membesar.
class RulePackLoader {
  RulePackLoader({
    http.Client? client,
    Future<Directory> Function()? dirProvider,
    AssetBundle? bundle,
    String? hostsUrl,
    String? sitesUrl,
  }) : _client = client,
       _dirProvider = dirProvider ?? getApplicationSupportDirectory,
       _bundle = bundle,
       _hostsUrlOverride = hostsUrl,
       _sitesUrlOverride = sitesUrl;

  static const String hostsAsset = 'assets/rules/hosts.txt';
  static const String sitesAsset = 'assets/rules/sites.json';
  static const String versionAsset = 'assets/rules/version.json';
  static const Duration timeout = Duration(seconds: 10);
  static const int minHostLines = 100;

  final http.Client? _client;
  final Future<Directory> Function() _dirProvider;
  final AssetBundle? _bundle;
  final String? _hostsUrlOverride;
  final String? _sitesUrlOverride;

  static final RegExp _hostLine = RegExp(r'^[a-z0-9.-]+$');

  AssetBundle get _assets => _bundle ?? rootBundle;

  // ---------------------------------------------------------------------------
  // Validasi (murni, dipakai test)
  // ---------------------------------------------------------------------------

  /// `null` = valid; selain itu alasan penolakan.
  static String? validateHosts(String content) {
    var count = 0;
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (!_hostLine.hasMatch(line)) return 'baris hosts korup: "$line"';
      count++;
    }
    if (count < minHostLines) {
      return 'hosts terlalu sedikit ($count < $minHostLines baris)';
    }
    return null;
  }

  static String? validateSites(String content) {
    try {
      final root = jsonDecode(content);
      if (root is! Map) return 'sites.json bukan objek';
      if (root['version'] is! int) return 'sites.json tanpa "version"';
      if (root['sites'] is! Map) return 'sites.json tanpa "sites"';
      return null;
    } catch (_) {
      return 'sites.json bukan JSON valid';
    }
  }

  static String labelOf(String sitesJson) {
    try {
      final root = jsonDecode(sitesJson) as Map;
      return '${root['version']} · ${root['updatedAt'] ?? '-'}';
    } catch (_) {
      return '-';
    }
  }

  // ---------------------------------------------------------------------------
  // URL
  // ---------------------------------------------------------------------------

  Future<({String hosts, String sites})> _urls() async {
    var hosts = _hostsUrlOverride ?? '';
    var sites = _sitesUrlOverride ?? '';
    if (hosts.isEmpty || sites.isEmpty) {
      try {
        final v = jsonDecode(await _assets.loadString(versionAsset)) as Map;
        if (hosts.isEmpty) hosts = (v['hostsUrl'] as String?) ?? '';
        if (sites.isEmpty) sites = (v['sitesUrl'] as String?) ?? '';
      } catch (error) {
        Log.e('rulepack', 'version.json tak terbaca', error);
      }
    }
    return (
      hosts: hosts.isEmpty ? kRuleHostsUrl : hosts,
      sites: sites.isEmpty ? kRuleSitesUrl : sites,
    );
  }

  /// Ada URL untuk update? Tombol Update disembunyikan bila tidak.
  Future<bool> get canUpdate async {
    final u = await _urls();
    return u.hosts.isNotEmpty && u.sites.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Muat
  // ---------------------------------------------------------------------------

  Future<File> _file(String name) async {
    final dir = Directory('${(await _dirProvider()).path}/rule_pack');
    await dir.create(recursive: true);
    return File('${dir.path}/$name');
  }

  /// Cache bila valid, kalau tidak asset. Tidak pernah melempar.
  Future<RulePack> load() async {
    try {
      final hosts = await _file('hosts.txt');
      final sites = await _file('sites.json');
      if (await hosts.exists() && await sites.exists()) {
        final h = await hosts.readAsString();
        final s = await sites.readAsString();
        if (validateHosts(h) == null && validateSites(s) == null) {
          return RulePack(
            hosts: h,
            sites: s,
            versionLabel: labelOf(s),
            fromCache: true,
          );
        }
        Log.e('rulepack', 'cache invalid, pakai asset bawaan');
      }
    } catch (error) {
      Log.e('rulepack', 'cache tak terbaca, pakai asset bawaan', error);
    }
    return _loadAssets();
  }

  Future<RulePack> _loadAssets() async {
    var h = '';
    var s = '{"version":0,"sites":{}}';
    try {
      h = await _assets.loadString(hostsAsset);
      s = await _assets.loadString(sitesAsset);
    } catch (error) {
      Log.e('rulepack', 'asset rule pack gagal dimuat (fail-open)', error);
    }
    return RulePack(
      hosts: h,
      sites: s,
      versionLabel: labelOf(s),
      fromCache: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  Future<UpdateResult> update() async {
    final urls = await _urls();
    if (urls.hosts.isEmpty || urls.sites.isEmpty) {
      return const UpdateResult.failure('URL rule pack belum dikonfigurasi');
    }
    final client = _client ?? http.Client();
    try {
      final hostsText = await _get(client, urls.hosts);
      final sitesText = await _get(client, urls.sites);

      final bad = validateHosts(hostsText) ?? validateSites(sitesText);
      if (bad != null) return UpdateResult.failure('Ditolak: $bad');

      await _writeAtomic('hosts.txt', hostsText);
      await _writeAtomic('sites.json', sitesText);

      final label = labelOf(sitesText);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(StorageKeys.rulesVersion, label);
      } catch (error) {
        Log.e('rulepack', 'gagal menyimpan versi', error);
      }
      return UpdateResult.success(
        'Rule pack diperbarui ke $label',
        RulePack(
          hosts: hostsText,
          sites: sitesText,
          versionLabel: label,
          fromCache: true,
        ),
      );
    } on SocketException {
      return const UpdateResult.failure('Tidak ada koneksi internet');
    } on http.ClientException {
      return const UpdateResult.failure('Tidak ada koneksi internet');
    } on TimeoutException {
      return const UpdateResult.failure('Waktu habis (10 detik)');
    } on HttpException catch (error) {
      return UpdateResult.failure(error.message);
    } on Exception catch (error) {
      return UpdateResult.failure('Gagal memperbarui: $error');
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<String> _get(http.Client client, String url) async {
    final response = await client.get(Uri.parse(url)).timeout(timeout);
    if (response.statusCode != 200) {
      throw HttpException('Server menjawab ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  /// Tulis `.tmp` lalu rename: cache lama tidak pernah setengah tertimpa.
  Future<void> _writeAtomic(String name, String content) async {
    final target = await _file(name);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target.path);
  }
}
