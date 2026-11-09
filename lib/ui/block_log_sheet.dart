import 'package:flutter/material.dart';

import '../adblock/block_log.dart';
import '../adblock/rule_engine.dart';

/// Bottom sheet log blokir: daftar per host, tombol Allow, dan bersihkan log.
Future<void> showBlockLogSheet(
  BuildContext context, {
  required BlockLog log,
  required RuleEngine engine,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlockLogSheet(log: log, engine: engine),
  );
}

class BlockLogSheet extends StatefulWidget {
  const BlockLogSheet({super.key, required this.log, required this.engine});

  final BlockLog log;
  final RuleEngine engine;

  @override
  State<BlockLogSheet> createState() => _BlockLogSheetState();
}

class _BlockLogSheetState extends State<BlockLogSheet> {
  String? _lastAllowed;

  Future<void> _allow(String host) async {
    await widget.engine.addToAllowlist(host);
    if (!mounted) return;
    setState(() => _lastAllowed = host);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$host diizinkan. Muat ulang halaman untuk menerapkan.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: maxHeight,
      child: ValueListenableBuilder<List<BlockLogEntry>>(
        valueListenable: widget.log.entries,
        builder: (context, entries, _) {
          final groups = <String, List<BlockLogEntry>>{};
          for (final entry in entries) {
            groups.putIfAbsent(entry.host, () => <BlockLogEntry>[]).add(entry);
          }
          final sorted = groups.entries.toList()
            ..sort((a, b) => b.value.length.compareTo(a.value.length));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Log blokir', style: textTheme.titleMedium),
                          Text(
                            '${widget.log.total} blokir · ${groups.length} host',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('btn-clear-log'),
                      onPressed: entries.isEmpty ? null : widget.log.clear,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Bersihkan'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Belum ada yang diblokir.\n'
                            'Buka situs dan mainkan video — iklan yang dicegat '
                            'akan muncul di sini.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) {
                          final group = sorted[index];
                          final host = group.key;
                          final latest = group.value.first;
                          final allowed =
                              widget.engine.isAllowlisted(host) ||
                              _lastAllowed == host;
                          return ListTile(
                            leading: Icon(
                              latest.kind == BlockKind.popup
                                  ? Icons.open_in_new_off
                                  : Icons.block,
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                            title: Text(
                              host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              '${group.value.length}× · ${latest.reason}'
                              '${latest.rule == null ? '' : ' · ${latest.rule}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            trailing: allowed
                                ? Chip(
                                    label: const Text('Diizinkan'),
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                    backgroundColor:
                                        colors.surfaceContainerHighest,
                                  )
                                : TextButton(
                                    key: Key('btn-allow-$host'),
                                    onPressed: () => _allow(host),
                                    child: const Text('Allow'),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
