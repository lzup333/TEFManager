import 'package:flutter/material.dart';

import '../app.dart';
import '../controllers/app_controller.dart';
import '../core/i18n.dart';
import '../data/resource_pack_store.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/component_card.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  PackType _type = PackType.language;
  bool _busy = false;

  static const _types = [
    _PackTab(
      PackType.language,
      'resource.language.title',
      Icons.translate_rounded,
    ),
    _PackTab(
      PackType.languagePatch,
      'resource.languagePatch',
      Icons.spellcheck_rounded,
    ),
    _PackTab(PackType.texture, 'resource.texture', Icons.image_outlined),
    _PackTab(
      PackType.font,
      'resource.font.title',
      Icons.font_download_outlined,
    ),
    _PackTab(PackType.audio, 'resource.audio.title', Icons.music_note_outlined),
  ];

  static IconData _iconFor(PackType type) =>
      _types.firstWhere((t) => t.type == type).icon;

  static String _labelFor(PackType type) =>
      tr(_types.firstWhere((t) => t.type == type).labelKey);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final snapshot = app.resources;
    final label = _labelFor(_type);
    final packs = snapshot.of(_type);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('resource.title')),
        actions: [
          IconButton(
            tooltip: tr('resource.add', {'packType': label}),
            onPressed: _busy ? null : () => _importPacks(context),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              itemCount: _types.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = _types[index];
                final count = snapshot.of(tab.type).length;
                return ChoiceChip(
                  avatar: Icon(tab.icon, size: 16),
                  label: Text('${tr(tab.labelKey)} ($count)'),
                  selected: _type == tab.type,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _type = tab.type),
                );
              },
            ),
          ),
          Expanded(
            child: packs.isEmpty
                ? EmptyState(
                    icon: _iconFor(_type),
                    title: tr('resource.empty', {'packType': label}),
                    message: tr('resource.emptyAction', {'packType': label}),
                    action: OutlinedButton.icon(
                      onPressed: () => _importPacks(context),
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(tr('resource.add', {'packType': label})),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 96),
                    itemCount: packs.length,
                    itemBuilder: (context, index) {
                      final pack = packs[index];
                      return _buildPackCard(
                        context,
                        app,
                        snapshot,
                        pack,
                        index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackCard(
    BuildContext context,
    AppController app,
    ResourcePackSnapshot snapshot,
    ResourcesPackItem pack,
    int index,
  ) {
    final enabled = snapshot.isEnabled(_type, pack.fileName);
    final id = pack.fileName.replaceAll('.zip', '');
    final canReorder = _type != PackType.font;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetails(context, pack, index, enabled),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ComponentIcon(
                file: app.resourceStore.iconFile(_type, id),
                fallback: _iconFor(_type),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pack.author} · v${pack.version}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (pack.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        pack.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      [
                        pack.type == PackOrigin.terraria
                            ? 'Terraria'
                            : 'TEFManager',
                        if (canReorder) '#${index + 1}',
                        if (enabled) tr('manager.loader.enabled'),
                      ].join('  ·  '),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_type == PackType.font)
                IconButton(
                  tooltip: enabled
                      ? tr('resource.action.deselect')
                      : tr('resource.action.select'),
                  onPressed: () async {
                    await app.setResourcePackEnabled(_type, pack, !enabled);
                  },
                  icon: Icon(
                    enabled
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: enabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Switch(
                  value: enabled,
                  onChanged: (value) => _toggle(context, app, pack, value),
                ),
              PopupMenuButton<String>(
                tooltip: '',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'up':
                      await app.moveResourcePack(_type, pack.fileName, true);
                    case 'down':
                      await app.moveResourcePack(_type, pack.fileName, false);
                    case 'delete':
                      await _confirmDelete(context, app, pack);
                    case 'details':
                      _showDetails(context, pack, index, enabled);
                  }
                },
                itemBuilder: (context) => [
                  if (canReorder)
                    PopupMenuItem(
                      value: 'up',
                      enabled: index > 0,
                      child: Text(tr('resource.action.up')),
                    ),
                  if (canReorder)
                    PopupMenuItem(
                      value: 'down',
                      enabled: true,
                      child: Text(tr('resource.action.down')),
                    ),
                  PopupMenuItem(
                    value: 'details',
                    child: Text(tr('manager.action.details')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      tr('manager.action.delete'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    AppController app,
    ResourcesPackItem pack,
    bool value,
  ) async {
    try {
      await app.setResourcePackEnabled(_type, pack, value);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('resource.limit', {
              'count': ResourcePackStore.languagePackLimit,
            }),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppController app,
    ResourcesPackItem pack,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('resource.delete.title', {'name': pack.name})),
        content: Text(tr('resource.delete.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.deleteResourcePack(_type, pack);
  }

  Future<void> _importPacks(BuildContext context) async {
    final app = AppScope.read(context);
    final paths = await app.pickPackageFiles();
    if (!context.mounted) return;
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('manager.import.empty'))));
      return;
    }

    final status = ValueNotifier<String>(tr('resource.installing'));
    setState(() => _busy = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('resource.install.title')),
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (context, value, _) => Text(value),
              ),
            ),
          ],
        ),
      ),
    );

    final results = await app.installResourcePacks(
      paths,
      onProgress: (phase) => status.value = tr('resource.installing'),
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _busy = false);
    status.dispose();

    final ok = results.where((r) => r.success).length;
    final fail = results.length - ok;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('resource.install.success')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('resource.install.result', {'ok': ok, 'fail': fail})),
            for (final result in results.where((r) => !r.success))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  result.error ?? 'unknown',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    ResourcesPackItem pack,
    int index,
    bool enabled,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                pack.name,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${pack.author} · v${pack.version}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  MetaChip(
                    label: pack.type == PackOrigin.terraria
                        ? 'Terraria'
                        : 'TEFManager',
                  ),
                  MetaChip(label: _labelFor(_type), tone: ChipTone.primary),
                  MetaChip(
                    label: enabled
                        ? tr('manager.loader.enabled')
                        : tr('manager.loader.disabled'),
                    tone: enabled ? ChipTone.success : ChipTone.neutral,
                  ),
                ],
              ),
              if (pack.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  tr('manager.details'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  pack.description,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(height: 1.5),
                ),
              ],
              const SizedBox(height: 16),
              SelectableText(
                pack.fileName,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PackTab {
  const _PackTab(this.type, this.labelKey, this.icon);

  final PackType type;
  final String labelKey;
  final IconData icon;
}
