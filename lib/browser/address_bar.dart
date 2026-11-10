import 'package:flutter/material.dart';

/// Baris alamat + tombol navigasi. Dumb widget: semua state ada di parent.
class AddressBar extends StatelessWidget {
  const AddressBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onStop,
    this.onMenuSelected,
    this.isBookmarked = false,
    this.onTogglePin,
    this.isPinned = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.isLoading = false,
    this.isSecure = true,
    this.progress = 0,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback onStop;

  /// Menu ⋮: nilai `bookmark`, `blocklog`, `settings`.
  final ValueChanged<String>? onMenuSelected;
  final bool isBookmarked;

  /// Tandai/lepas situs video (halaman terkunci + sweep kosmetik).
  final VoidCallback? onTogglePin;
  final bool isPinned;

  final bool canGoBack;
  final bool canGoForward;
  final bool isLoading;
  final bool isSecure;

  /// 0..1
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _NavButton(
                    key: const Key('btn-back'),
                    icon: Icons.arrow_back_ios_new,
                    tooltip: 'Kembali',
                    onPressed: canGoBack ? onBack : null,
                  ),
                  _NavButton(
                    key: const Key('btn-forward'),
                    icon: Icons.arrow_forward_ios,
                    tooltip: 'Maju',
                    onPressed: canGoForward ? onForward : null,
                  ),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        return TextField(
                          key: const Key('address-bar-field'),
                          controller: controller,
                          focusNode: focusNode,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          autocorrect: false,
                          enableSuggestions: false,
                          onSubmitted: onSubmitted,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Cari atau ketik alamat',
                            filled: true,
                            fillColor: colors.surfaceContainerHighest,
                            prefixIcon: Icon(
                              isSecure ? Icons.lock_outline : Icons.public,
                              size: 15,
                              color: colors.onSurfaceVariant,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            suffixIcon: value.text.isEmpty || isLoading
                                ? null
                                : IconButton(
                                    key: const Key('btn-clear-address'),
                                    icon: const Icon(Icons.close, size: 16),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 30,
                                      minHeight: 30,
                                    ),
                                    tooltip: 'Hapus',
                                    onPressed: () {
                                      controller.clear();
                                      focusNode.requestFocus();
                                    },
                                  ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _NavButton(
                    key: const Key('btn-reload'),
                    icon: isLoading ? Icons.close : Icons.refresh,
                    tooltip: isLoading ? 'Berhenti' : 'Muat ulang',
                    onPressed: isLoading ? onStop : onReload,
                  ),
                  _NavButton(
                    key: const Key('btn-pin'),
                    icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    tooltip: isPinned
                        ? 'Lepas tanda situs video'
                        : 'Tandai situs video',
                    onPressed: onTogglePin,
                  ),
                  PopupMenuButton<String>(
                    key: const Key('btn-menu'),
                    tooltip: 'Menu',
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: const EdgeInsets.all(8),
                    onSelected: onMenuSelected,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'bookmark',
                        child: Text(
                          isBookmarked ? 'Hapus bookmark' : 'Tambah bookmark',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'blocklog',
                        child: Text('Log blokir'),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Text('Pengaturan'),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                height: 2,
                child: isLoading
                    ? LinearProgressIndicator(
                        value: progress > 0 && progress < 1 ? progress : null,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
