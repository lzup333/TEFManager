import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import 'common.dart';

class ComponentIcon extends StatefulWidget {
  const ComponentIcon({
    super.key,
    this.file,
    this.size = 46,
    this.fallback = Icons.extension_rounded,
  });

  final File? file;
  final double size;
  final IconData fallback;

  @override
  State<ComponentIcon> createState() => _ComponentIconState();
}

class _ComponentIconState extends State<ComponentIcon> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ComponentIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file?.path != widget.file?.path) {
      _bytes = null;
      _loaded = false;
      _load();
    }
  }

  Future<void> _load() async {
    final file = widget.file;
    if (file == null) return;
    try {
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _bytes = bytes);
      }
    } catch (_) {
      // Fall back to the icon below.
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (_bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.memory(
          _bytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              IconBadge(icon: widget.fallback, size: size),
        ),
      );
    }
    if (!_loaded) {
      return SizedBox(width: size, height: size);
    }
    return IconBadge(icon: widget.fallback, size: size);
  }
}

class ComponentCard extends StatelessWidget {
  const ComponentCard({
    super.key,
    required this.title,
    required this.pkgId,
    required this.version,
    required this.author,
    this.brief,
    this.icon,
    this.enabled,
    this.onToggle,
    this.onTap,
    this.onDelete,
    this.essential = false,
    this.hasUpdate = false,
  });

  final String title;
  final String pkgId;
  final String version;
  final String author;
  final String? brief;
  final File? icon;
  final bool? enabled;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool essential;
  final bool hasUpdate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dimmed = enabled == false;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: dimmed ? 0.55 : 1,
                child: ComponentIcon(file: icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? pkgId : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: dimmed
                                      ? scheme.onSurfaceVariant
                                      : null,
                                ),
                          ),
                        ),
                        if (essential)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: MetaChip(
                              label: tr('manager.module.essential'),
                              tone: ChipTone.warning,
                            ),
                          ),
                        if (hasUpdate)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: MetaChip(
                              label: tr('manager.hasUpdate'),
                              tone: ChipTone.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pkgId  ·  v$version',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (author.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (brief != null && brief!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        brief!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onToggle != null)
                    Switch(value: enabled ?? false, onChanged: onToggle),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      tooltip: '',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) {
                        if (value == 'details') onTap?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'details',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.info_outline_rounded),
                            title: Text(tr('manager.action.details')),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: scheme.error,
                            ),
                            title: Text(
                              tr('manager.action.delete'),
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
