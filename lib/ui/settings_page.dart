import 'package:flutter/material.dart';

import '../adblock/block_log.dart';
import '../adblock/rule_engine.dart';
import '../adblock/rule_pack_loader.dart';
import '../adblock/site_profiles.dart';
import '../core/constants.dart';
import '../data/bookmark_store.dart';
import '../data/history_store.dart';
import '../data/settings_store.dart';
import 'block_log_sheet.dart';

/// Pengaturan: toggle iklan, rule pack, situs, allowlist, host terpelajari,
/// bookmark, history, log blokir, info app.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.engine,
    required this.log,
    required this.loader,
    required this.history,
    required this.bookmarks,
    required this.baseProfiles,
    required this.versionLabel,
    required this.onUpdate,
    required this.onOpenUrl,
  });

  final SettingsStore settings;
  final RuleEngine engine;
  final BlockLog log;
  final RulePackLoader loader;
  final HistoryStore history;
  final BookmarkStore bookmarks;
  final SiteProfiles Function() baseProfiles;
  final String Function() versionLabel;
  final Future<UpdateResult> Function() onUpdate;
  final void Function(String url) onOpenUrl;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _updating = false;
  bool _canUpdate = false;
  String? _updateResult;

  @override
  void initState() {
    super.initState();
    widget.loader.canUpdate.then((v) {
      if (mounted) setState(() => _canUpdate = v);
    });
  }

  Future<void> _update() async {
    setState(() {
      _updating = true;
      _updateResult = null;
    });
    final result = await widget.onUpdate();
    if (!mounted) return;
    setState(() {
      _updating = false;
      _updateResult = '${result.ok ? 'Berhasil' : 'Gagal'}: ${result.message}';
    });
  }

  void _open(String url) {
    widget.onOpenUrl(url);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final base = widget.baseProfiles();
          final profiles = base.all.toList()
            ..sort((a, b) => a.domain.compareTo(b.domain));
          final allowlist = widget.engine.allowlist.toList()..sort();
          final learned = widget.engine.learned.toList()..sort();
          final userSites = s.userSites.toList()..sort();
          return ListView(
            children: [
              SwitchListTile(
                key: const Key('switch-adblock'),
                title: const Text('Blokir iklan'),
                subtitle: const Text('Berlaku langsung di semua tab'),
                value: s.adblockEnabled,
                onChanged: s.setAdblockEnabled,
              ),
              const Divider(),
              _header('Rule pack'),
              ListTile(
                title: const Text('Versi'),
                subtitle: Text(
                  '${widget.versionLabel()} · ${widget.engine.hostCount} host',
                ),
              ),
              if (_canUpdate)
                ListTile(
                  key: const Key('btn-update-rules'),
                  leading: _updating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt),
                  title: const Text('Update sekarang'),
                  subtitle: _updateResult == null ? null : Text(_updateResult!),
                  onTap: _updating ? null : _update,
                )
              else
                const ListTile(
                  title: Text('Update rule pack'),
                  subtitle: Text('URL rule pack belum dikonfigurasi'),
                ),
              const Divider(),
              _header('Situs video'),
              for (final p in profiles)
                SwitchListTile(
                  title: Text(p.domain),
                  subtitle: p.note.isEmpty
                      ? null
                      : Text(
                          p.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  value: s.siteOverrides[p.domain] ?? p.enabled,
                  onChanged: (v) => s.setSiteEnabled(p.domain, v),
                ),
              for (final d in userSites)
                ListTile(
                  title: Text(d),
                  subtitle: const Text('Ditandai pengguna'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Lepas tanda',
                    onPressed: () => s.toggleUserSite(d),
                  ),
                ),
              const Divider(),
              _header('Allowlist'),
              if (allowlist.isEmpty) _empty('Kosong'),
              for (final h in allowlist)
                ListTile(
                  title: Text(h),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Hapus dari allowlist',
                    onPressed: () async {
                      await widget.engine.removeFromAllowlist(h);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              const Divider(),
              _header('Host iklan terpelajari'),
              if (learned.isEmpty) _empty('Belum ada'),
              for (final h in learned)
                ListTile(
                  title: Text(h),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Lepas blokir',
                    onPressed: () async {
                      await widget.engine.unlearn(h);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              const Divider(),
              _header('Bookmark'),
              if (widget.bookmarks.items.isEmpty) _empty('Kosong'),
              for (final b in widget.bookmarks.items)
                ListTile(
                  title: Text(
                    b.title.isEmpty ? b.url : b.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(b.url, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(b.url),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Hapus bookmark',
                    onPressed: () async {
                      await widget.bookmarks.remove(b.url);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              const Divider(),
              _header('History'),
              if (widget.history.entries.isEmpty) _empty('Kosong'),
              for (final e in widget.history.entries.take(30))
                ListTile(
                  dense: true,
                  title: Text(
                    e.title.isEmpty ? e.url : e.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(e.url, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(e.url),
                ),
              ListTile(
                key: const Key('btn-clear-history'),
                leading: const Icon(Icons.history_toggle_off),
                title: const Text('Bersihkan history'),
                onTap: () async {
                  await widget.history.clear();
                  if (mounted) setState(() {});
                },
              ),
              const Divider(),
              _header('Log blokir'),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Buka log blokir'),
                onTap: () => showBlockLogSheet(
                  context,
                  log: widget.log,
                  engine: widget.engine,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Bersihkan log blokir'),
                onTap: () {
                  widget.log.clear();
                  setState(() {});
                },
              ),
              const Divider(),
              _header('Tentang'),
              const ListTile(
                title: Text(AppInfo.name),
                subtitle: Text(
                  'Versi ${AppInfo.version} · ${AppInfo.packageId}',
                ),
              ),
              const ListTile(
                title: Text('Format rule'),
                subtitle: Text('docs/RULES-FORMAT.md di repo'),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}
