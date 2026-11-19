import 'package:flutter/material.dart';

import '../app.dart';
import '../core/i18n.dart';
import '../data/instance_store.dart';
import '../widgets/common.dart';

class InstanceScreen extends StatefulWidget {
  const InstanceScreen({super.key});

  @override
  State<InstanceScreen> createState() => _InstanceScreenState();
}

class _InstanceScreenState extends State<InstanceScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final state = app.instances;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('instance.title')),
        actions: [
          IconButton(
            tooltip: tr('refresh'),
            onPressed: _busy ? null : () => _refresh(context),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: tr('instance.import'),
            onPressed: _busy ? null : () => _import(context),
            icon: const Icon(Icons.file_download_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: '',
            icon: const Icon(Icons.add_rounded),
            onSelected: (value) => _create(context, clone: value == 'clone'),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'empty',
                child: Text(tr('instance.createEmpty')),
              ),
              PopupMenuItem(
                value: 'clone',
                child: Text(tr('instance.cloneCurrent')),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(
                tr('settings.general.instanceDesc'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final instance in state.items)
              _InstanceCard(
                instance: instance,
                active: instance.id == state.activeId,
                busy: _busy,
                onSwitch: () => _switch(instance),
                onClone: () => _clone(context, instance),
                onExport: () => _export(context, instance),
                onDelete: instance.isDefault
                    ? null
                    : () => _delete(context, instance),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final app = AppScope.read(context);
    await app.reloadInstances();
    if (mounted) setState(() {});
  }

  Future<void> _switch(AppInstance instance) async {
    final app = AppScope.read(context);
    setState(() => _busy = true);
    await app.switchInstance(instance.id);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _create(BuildContext context, {required bool clone}) async {
    final name = await _askName(
      context,
      title: clone ? tr('instance.cloneCurrent') : tr('instance.createEmpty'),
    );
    if (name == null || !mounted) return;
    final app = AppScope.read(context);
    setState(() => _busy = true);
    await app.createInstance(name, cloneCurrent: clone);
    await app.reloadInstances();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('instance.created'))));
  }

  Future<void> _clone(BuildContext context, AppInstance instance) async {
    final app = AppScope.read(context);
    setState(() => _busy = true);
    await app.cloneInstance(instance);
    await app.reloadInstances();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('instance.created'))));
  }

  Future<String?> _askName(BuildContext context, {required String title}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr('instance.name'),
            hintText: tr('instance.nameHint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(context, value.isEmpty ? null : value);
            },
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final app = AppScope.read(context);
    final paths = await app.pickPackageFiles();
    if (!mounted || paths.isEmpty) return;
    setState(() => _busy = true);
    final created = await app.importInstance(paths.first);
    await app.reloadInstances();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created != null
              ? tr('instance.imported')
              : tr('instance.importFailed'),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, AppInstance instance) async {
    var includePacks = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('instance.exportOptions')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('instance.exportHint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('instance.includePacks')),
                subtitle: Text(tr('instance.includePacksDesc')),
                value: includePacks,
                onChanged: (value) =>
                    setDialogState(() => includePacks = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('instance.export')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final app = AppScope.read(context);
    setState(() => _busy = true);
    final path = await app.exportInstance(
      instance,
      includeResourcePacks: includePacks,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('instance.exportFailed'))));
      return;
    }
    final saved = await app.exportFile(
      path,
      '${instance.name}.tefinstance.zip',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? tr('instance.exported') : tr('instance.exportFailed'),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, AppInstance instance) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('instance.deleteTitle', {'name': instance.name})),
        content: Text(tr('instance.deleteBody')),
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
    if (ok != true || !mounted) return;
    final app = AppScope.read(context);
    setState(() => _busy = true);
    await app.deleteInstance(instance);
    await app.reloadInstances();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('instance.deleted'))));
  }
}

class _InstanceCard extends StatelessWidget {
  const _InstanceCard({
    required this.instance,
    required this.active,
    required this.busy,
    required this.onSwitch,
    required this.onClone,
    required this.onExport,
    required this.onDelete,
  });

  final AppInstance instance;
  final bool active;
  final bool busy;
  final VoidCallback onSwitch;
  final VoidCallback onClone;
  final VoidCallback onExport;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final created = instance.createdAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(instance.createdAt)
        : null;
    final subtitle = [
      instance.isDefault ? tr('instance.default') : tr('instance.custom'),
      if (created != null)
        tr('instance.createdAt', {
          'date':
              '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}',
        }),
    ].join('  ·  ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: active ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: active || busy ? null : onSwitch,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              IconBadge(
                icon: active ? Icons.layers_rounded : Icons.layers_outlined,
                size: 42,
                color: active ? scheme.primary : scheme.surfaceContainerHighest,
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
                            instance.isDefault
                                ? tr('instance.default')
                                : instance.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (active)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: MetaChip(
                              label: tr('instance.active'),
                              tone: ChipTone.success,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '',
                enabled: !busy,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'switch':
                      onSwitch();
                    case 'clone':
                      onClone();
                    case 'export':
                      onExport();
                    case 'delete':
                      onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (!active)
                    PopupMenuItem(
                      value: 'switch',
                      child: Text(tr('instance.switch')),
                    ),
                  PopupMenuItem(
                    value: 'clone',
                    child: Text(tr('instance.clone')),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text(tr('instance.export')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: onDelete != null,
                    child: Text(
                      tr('instance.delete'),
                      style: TextStyle(
                        color: onDelete == null ? null : scheme.error,
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
}
