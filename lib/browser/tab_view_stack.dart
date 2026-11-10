import 'package:flutter/material.dart';

import 'tab_manager.dart';

/// `IndexedStack` semua tab: WebView tab non-aktif tetap hidup (tidak reload,
/// posisi scroll terjaga).
class TabViewStack extends StatelessWidget {
  const TabViewStack({super.key, required this.manager, required this.builder});

  final TabManager manager;
  final Widget Function(BrowserTab tab) builder;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: manager.activeIndex,
      children: [
        for (final tab in manager.tabs)
          KeyedSubtree(key: ValueKey(tab.id), child: builder(tab)),
      ],
    );
  }
}

/// Baris tab: judul pendek + tombol tutup, dan tombol tab baru.
class TabStrip extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.manager,
    required this.onSelect,
    required this.onClose,
    required this.onNew,
  });

  final TabManager manager;
  final ValueChanged<BrowserTab> onSelect;
  final ValueChanged<BrowserTab> onClose;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      color: colors.surfaceContainerHigh,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final tab in manager.tabs)
                  _TabChip(
                    tab: tab,
                    selected: tab == manager.active,
                    onTap: () => onSelect(tab),
                    onClose: () => onClose(tab),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const Key('btn-new-tab'),
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Tab baru',
            visualDensity: VisualDensity.compact,
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: selected ? colors.surface : null,
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: selected ? colors.primary : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            InkWell(
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
