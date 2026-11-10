import 'dart:convert';

import 'site_profiles.dart';

/// Pembuat skrip kosmetik (JS) yang disuntik `AT_DOCUMENT_START`.
///
/// Keputusan: satu skrip memuat **semua** profil aktif dan memilih profil dari
/// `location.hostname` saat runtime. `UserScript` hanya bisa dipasang saat
/// WebView dibuat, sedangkan host tujuan baru diketahui kemudian. Host tanpa
/// profil → skrip tidak melakukan apa pun (aman untuk x.com, login, dsb.).
class CosmeticScript {
  CosmeticScript._();

  static String build(SiteProfiles profiles) {
    final data = jsonEncode([
      for (final p in profiles.all)
        if (p.enabled) p.toJson(),
    ]);
    return _template.replaceFirst('__PROFILES__', data);
  }

  // IIFE, tanpa variabel global dan tanpa atribut DOM yang mudah dideteksi
  // (elemen yang disembunyikan dicatat di WeakSet lokal).
  static const String _template = r'''
(function () {
  try {
    var PROFILES = __PROFILES__;
    var host = location.hostname.toLowerCase().replace(/^www\./, '');
    var prof = null;
    for (var i = 0; i < PROFILES.length; i++) {
      var d = PROFILES[i].domain;
      if ((host === d || host.slice(-(d.length + 1)) === '.' + d) &&
          (!prof || d.length > prof.domain.length)) prof = PROFILES[i];
    }
    if (!prof) return;

    var internal = false;
    var hidden = new WeakSet();
    var clicked = new WeakSet();
    var PLAYER = 'video,.jwplayer,.plyr,[class*=player]';
    var CLOSE_TEXT = ['×', '✕', '✖', 'x', 'close', 'skip',
                      'tutup', 'lewati'];

    function install() {
      try { window.open = function () { return null; }; } catch (e) {}
      try {
        Object.defineProperty(window, 'onbeforeunload', {
          get: function () { return null; },
          set: function () {},
          configurable: true
        });
      } catch (e) {}
      try {
        var alerts = 0, oa = window.alert;
        window.alert = function () {
          if (alerts++ < 1) return oa.apply(window, arguments);
        };
      } catch (e) {}

      document.addEventListener('click', function (ev) {
        try {
          if (internal) return;
          if (ev.isTrusted === false) { ev.preventDefault(); return; }
          var a = ev.target && ev.target.closest && ev.target.closest('a[href]');
          if (!a) return;
          var u = new URL(a.href, location.href);
          var scheme = u.protocol.replace(':', '');
          if (/^(intent|market|tel|sms)$/.test(scheme)) {
            ev.preventDefault();
            return;
          }
          if (a.target === '_blank' && u.origin !== location.origin) {
            ev.preventDefault();
          }
        } catch (e) {}
      }, true);
    }

    function safeAll(sel) {
      try { return document.querySelectorAll(sel); } catch (e) { return []; }
    }

    function hide(el) {
      if (hidden.has(el)) return;
      hidden.add(el);
      el.style.setProperty('display', 'none', 'important');
    }

    function tryClose(root) {
      // Tombol close asli; jangan klik yang membuka link eksternal.
      var cands = [];
      (prof.closeSelectors || []).forEach(function (s) {
        root.querySelectorAll && root.querySelectorAll(s).forEach(function (n) {
          cands.push(n);
        });
      });
      if (root.querySelectorAll) {
        root.querySelectorAll('button,span,div,a').forEach(function (n) {
          if (n.children.length > 0) return;
          var t = (n.textContent || '').trim().toLowerCase();
          if (t && t.length <= 6 && CLOSE_TEXT.indexOf(t) >= 0) cands.push(n);
        });
      }
      cands.forEach(clickOnce);
    }

    function clickOnce(n) {
      if (clicked.has(n)) return;
      clicked.add(n);
      var a = n.closest && n.closest('a[href]');
      try {
        if (a && new URL(a.href, location.href).origin !== location.origin) {
          return;
        }
      } catch (e) { return; }
      internal = true;
      try { n.click(); } catch (e) {}
      internal = false;
    }

    function isOverlay(el, vw, vh) {
      var cs = getComputedStyle(el);
      if (cs.position !== 'fixed' && cs.position !== 'absolute') return false;
      if ((parseInt(cs.zIndex, 10) || 0) < 1000) return false;
      var r = el.getBoundingClientRect();
      if (r.width * r.height < vw * vh * 0.25) return false;
      if (el.closest(PLAYER) || el.querySelector(PLAYER)) return false;
      var hasAd = el.tagName === 'IFRAME' || el.querySelector('iframe') ||
        Array.prototype.some.call(el.querySelectorAll('a[href]'), function (a) {
          try { return new URL(a.href, location.href).origin !== location.origin; }
          catch (e) { return false; }
        }) ||
        Array.prototype.some.call(el.querySelectorAll('img'), function (im) {
          return im.width * im.height > vw * vh * 0.1;
        });
      return !!hasAd;
    }

    function sweep() {
      try {
        (prof.selectors || []).forEach(function (s) {
          safeAll(s).forEach(function (el) { hide(el); });
        });
        var vw = window.innerWidth || 1, vh = window.innerHeight || 1;
        var els = safeAll('div,iframe,aside,section,a');
        var n = Math.min(els.length, 1500);
        for (var i = 0; i < n; i++) {
          var el = els[i];
          if (hidden.has(el)) continue;
          if (isOverlay(el, vw, vh)) {
            tryClose(el);
            hide(el);
          }
        }
        (prof.closeSelectors || []).forEach(function (s) {
          safeAll(s).forEach(clickOnce);
        });
      } catch (e) {}
    }

    var timer = null;
    function schedule() {
      if (timer) clearTimeout(timer);
      timer = setTimeout(sweep, 300);
    }

    function start() {
      install();
      document.addEventListener('DOMContentLoaded', sweep);
      window.addEventListener('load', function () {
        sweep();
        setTimeout(sweep, 1500);
      });
      try {
        new MutationObserver(schedule).observe(document.documentElement, {
          childList: true,
          subtree: true
        });
      } catch (e) {}
    }

    if (prof.stealth) Promise.resolve().then(start); else start();
  } catch (e) {}
})();
''';
}
