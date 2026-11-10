import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../adblock/cosmetic_script.dart';
import '../adblock/site_profiles.dart';
import '../browser/webview_setup.dart';

/// Harness offline M3 (hanya debug; dibuka dengan mengetik `cb:test` di
/// address bar). Memakai profil sendiri untuk host `cosmetic.test`, jadi tidak
/// menyentuh `sites.json`.
class CosmeticTestPage extends StatelessWidget {
  const CosmeticTestPage({super.key});

  static const _profileJson =
      '{"sites":{"cosmetic.test":{"enabled":true,"stealth":false}}}';

  @override
  Widget build(BuildContext context) {
    final script = CosmeticScript.build(SiteProfiles.fromJson(_profileJson));
    return Scaffold(
      appBar: AppBar(title: const Text('Harness kosmetik (debug)')),
      body: InAppWebView(
        initialSettings: buildWebViewSettings(),
        initialUserScripts: UnmodifiableListView([
          UserScript(
            source: script,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: false,
          ),
        ]),
        initialData: InAppWebViewInitialData(
          data: _html,
          baseUrl: WebUri('https://cosmetic.test/'),
        ),
      ),
    );
  }

  static const String _html = r'''
<!doctype html><html><head><meta name="viewport" content="width=device-width">
<style>body{font-family:sans-serif;padding:12px}</style></head><body>
<h3>Harness M3</h3>
<p>Kasus 3: ketuk link ini &mdash; tidak boleh membuka apa pun:
<a id="ext" target="_blank" href="https://example.org/">link _blank eksternal</a></p>
<div class="player" id="player" style="width:100%;height:160px;background:#222;color:#fff">
  <video controls width="100%" height="140"></video>
</div>
<div id="keep" style="position:fixed;z-index:1500;left:0;bottom:0;width:100%;height:35%;background:#cde">
  <div class="jwplayer">player kedua (harus tetap tampil)</div>
  <a href="https://example.org/">link eksternal di dalam container player</a>
</div>
<pre id="out">menunggu 2.5 detik...</pre>
<div id="ovl" style="position:fixed;z-index:9999;left:0;top:0;width:100%;height:100%;background:rgba(255,0,0,.85);color:#fff">
  <p>OVERLAY IKLAN</p>
  <a href="https://ads.example.net/x">iklan</a>
  <button onclick="window.open('https://ads.example.net/pop')">&times;</button>
  <button onclick="location.href='https://ads.example.net/'">Lanjutkan</button>
</div>
<script>
setTimeout(function(){
  function vis(id){return getComputedStyle(document.getElementById(id)).display!=='none';}
  document.getElementById('out').textContent =
    '1 overlay hilang: ' + !vis('ovl') + '\n' +
    'player utuh: ' + (vis('player') && vis('keep')) + '\n' +
    '2/4: tombol palsu ikut hilang bersama overlay';
}, 2500);
</script></body></html>
''';
}
