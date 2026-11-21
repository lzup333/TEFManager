import 'dart:io';

import 'package:flutter/material.dart';

import '../app.dart';
import '../controllers/app_controller.dart';
import '../core/i18n.dart';
import '../data/component_store.dart';
import '../data/mod_repository.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/component_card.dart';
import 'json_ui_screen.dart';
import 'mod_settings_screen.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  int _tab = 0;
  String _category = 'module';
  String _query = '';
  bool _busy = false;
  bool _storeRequested = false;
  String? _storeLoaderFilter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final components = app.components;
    final categories = _categories(components);
    if (_tab == 1 && !_storeRequested) {
      _storeRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppScope.read(context).refreshStore();
      });
    }

    // Reset the selection if a loader was deleted.
    if (!categories.any((c) => c.id == _category)) {
      _category = categories.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('manager.title')),
        actions: [
          if (_tab == 0 && _category.startsWith('loader:'))
            IconButton(
              tooltip: tr('manager.group.manage'),
              onPressed: () => _showGroupManager(
                context,
                app,
                _category.substring('loader:'.length),
              ),
              icon: const Icon(Icons.folder_outlined),
            ),
          IconButton(
            tooltip: tr('manager.add'),
            onPressed: _busy ? null : () => _importPackages(context),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(tr('manager.tab.installed')),
                ),
                ButtonSegment(
                  value: 1,
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text(tr('manager.tab.repository')),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _buildInstalled(context, app, components, categories)
                : _buildStore(context),
          ),
        ],
      ),
    );
  }

  List<_Category> _categories(ComponentSnapshot components) {
    return [
      _Category('module', tr('manager.kind.module'), components.modules.length),
      _Category('plugin', tr('manager.kind.plugin'), components.plugins.length),
      _Category(
        'modloader',
        tr('manager.kind.loader'),
        components.loaders.length,
      ),
      for (final loader in components.loaders)
        _Category(
          'loader:${loader.pkgId}',
          loader.name.isEmpty ? loader.pkgId : loader.name,
          components.mods[loader.pkgId]?.length ?? 0,
        ),
    ];
  }

  Widget _buildInstalled(
    BuildContext context,
    AppController app,
    ComponentSnapshot components,
    List<_Category> categories,
  ) {
    return Column(
      children: [
        SearchField(
          hint: tr('manager.searchMod'),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              final selected = category.id == _category;
              return ChoiceChip(
                label: Text('${category.label} (${category.count})'),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _category = category.id),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _buildList(context, app, components)),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    AppController app,
    ComponentSnapshot components,
  ) {
    if (_category.startsWith('loader:')) {
      final loaderId = _category.substring('loader:'.length);
      final loader = components.loaders.where((l) => l.pkgId == loaderId);
      if (loader.isEmpty) {
        return EmptyState(
          icon: Icons.widgets_outlined,
          title: tr('manager.empty.title'),
          message: tr('manager.empty.message'),
        );
      }
      final enabled = components.enabledLoaders.contains(loaderId);
      if (!enabled) {
        return EmptyState(
          icon: Icons.power_settings_new_rounded,
          title: tr('manager.modloader.disabled'),
          message: tr('manager.modloader.disabledHint', {
            'loader': loader.first.name,
          }),
          action: FilledButton.icon(
            onPressed: () =>
                app.setComponentEnabled(AddonKind.modLoader, loaderId, true),
            icon: const Icon(Icons.toggle_on_rounded),
            label: Text(tr('manager.loader.enabled')),
          ),
        );
      }
      final mods = components.mods[loaderId] ?? const <ModItem>[];
      final filtered = _filter(
        mods,
        (m) =>
            '${m.name} ${m.pkgId} ${m.author} ${m.brieflyDescribe} ${m.description}',
      );
      if (filtered.isEmpty) return _empty();

      final groups = app.modGroups.groups;
      if (groups.isEmpty || _query.isNotEmpty) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildModCard(
            context,
            app,
            components,
            loaderId,
            filtered[index],
          ),
        );
      }

      final buckets = <String, List<ModItem>>{
        for (final group in groups) group.id: [],
        '': [],
      };
      for (final mod in filtered) {
        final gid = app.modGroups.groupIdOf(loaderId, mod.pkgId) ?? '';
        buckets.putIfAbsent(gid, () => []).add(mod);
      }

      final children = <Widget>[];
      for (final group in groups) {
        final items = buckets[group.id] ?? const <ModItem>[];
        if (items.isEmpty) continue;
        children.add(
          _ModGroupHeader(
            name: group.name,
            count: items.length,
            onRename: () => _renameGroup(context, app, group.id, group.name),
            onDelete: () => _deleteGroup(context, app, group.id, group.name),
          ),
        );
        children.addAll(
          items.map(
            (mod) => _buildModCard(context, app, components, loaderId, mod),
          ),
        );
      }
      final ungrouped = buckets[''] ?? const <ModItem>[];
      if (ungrouped.isNotEmpty) {
        children.add(
          _ModGroupHeader(
            name: tr('manager.group.ungrouped'),
            count: ungrouped.length,
          ),
        );
        children.addAll(
          ungrouped.map(
            (mod) => _buildModCard(context, app, components, loaderId, mod),
          ),
        );
      }
      if (children.isEmpty) return _empty();
      return ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: children,
      );
    }

    switch (_category) {
      case 'module':
        final items = _filter(
          components.modules,
          (m) =>
              '${m.name} ${m.pkgId} ${m.author} ${m.brieflyDescribe} ${m.description}',
        );
        if (items.isEmpty) return _empty();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final module = items[index];
            return ComponentCard(
              title: module.name,
              pkgId: module.pkgId,
              version: module.version,
              author: module.author,
              brief: module.brieflyDescribe,
              icon: app.componentStore.iconFile(AddonKind.module, module.pkgId),
              enabled: components.isEnabled(AddonKind.module, module.pkgId),
              onToggle: (value) => app.setComponentEnabled(
                AddonKind.module,
                module.pkgId,
                value,
              ),
              onTap: () => _showModuleDetails(context, module),
              onDelete: () => _confirmDelete(
                context,
                app,
                AddonKind.module,
                module.pkgId,
                module.name,
              ),
            );
          },
        );
      case 'plugin':
        final items = _filter(
          components.plugins,
          (m) => '${m.name} ${m.pkgId} ${m.author} ${m.description}',
        );
        if (items.isEmpty) return _empty();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final plugin = items[index];
            return ComponentCard(
              title: plugin.name,
              pkgId: plugin.pkgId,
              version: plugin.version,
              author: plugin.author,
              icon: app.componentStore.iconFile(AddonKind.plugin, plugin.pkgId),
              onTap: () => _showPluginDetails(context, plugin),
              onDelete: () => _confirmDelete(
                context,
                app,
                AddonKind.plugin,
                plugin.pkgId,
                plugin.name,
              ),
            );
          },
        );
      case 'modloader':
        final items = _filter(
          components.loaders,
          (m) =>
              '${m.name} ${m.pkgId} ${m.author} ${m.brieflyDescribe} ${m.description}',
        );
        if (items.isEmpty) return _empty();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final loader = items[index];
            final enabled = components.isEnabled(
              AddonKind.modLoader,
              loader.pkgId,
            );
            return ComponentCard(
              title: loader.name,
              pkgId: loader.pkgId,
              version: loader.version,
              author: loader.author,
              brief: loader.brieflyDescribe,
              icon: app.componentStore.iconFile(
                AddonKind.modLoader,
                loader.pkgId,
              ),
              enabled: enabled,
              onToggle: (value) => app.setComponentEnabled(
                AddonKind.modLoader,
                loader.pkgId,
                value,
              ),
              onTap: () => _showLoaderDetails(context, loader, enabled),
              onDelete: () => _confirmDelete(
                context,
                app,
                AddonKind.modLoader,
                loader.pkgId,
                loader.name,
              ),
            );
          },
        );
    }
    return _empty();
  }

  Widget _buildModCard(
    BuildContext context,
    AppController app,
    ComponentSnapshot components,
    String loaderId,
    ModItem mod,
  ) {
    final hasGroups = app.modGroups.groups.isNotEmpty;
    return ComponentCard(
      title: mod.name,
      pkgId: mod.pkgId,
      version: mod.version,
      author: mod.author,
      brief: mod.brieflyDescribe,
      icon: app.componentStore.iconFile(
        AddonKind.mod,
        mod.pkgId,
        loaderId: loaderId,
      ),
      enabled: components.isEnabled(
        AddonKind.mod,
        mod.pkgId,
        loaderId: loaderId,
      ),
      onToggle: (value) => app.setComponentEnabled(
        AddonKind.mod,
        mod.pkgId,
        value,
        loaderId: loaderId,
      ),
      onTap: () => _showModDetails(context, app, mod, loaderId),
      onDelete: () => _confirmDelete(
        context,
        app,
        AddonKind.mod,
        mod.pkgId,
        mod.name,
        loaderId: loaderId,
      ),
      onMoveGroup: hasGroups
          ? () => _showMoveGroup(context, app, loaderId, mod)
          : () => _showGroupManager(context, app, loaderId),
    );
  }

  Future<void> _showGroupManager(
    BuildContext context,
    AppController app,
    String loaderId,
  ) async {
    final nameController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final groups = app.modGroups.groups;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('manager.group.title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: tr('manager.group.hint'),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        await app.createModGroup(name);
                        nameController.clear();
                        setSheetState(() {});
                      },
                      child: Text(tr('manager.group.create')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      tr('manager.group.empty'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(group.name),
                          subtitle: Text(
                            tr('manager.group.count', {
                              'count':
                                  app.components.mods[loaderId]
                                      ?.where(
                                        (m) =>
                                            app.modGroups.groupIdOf(
                                              loaderId,
                                              m.pkgId,
                                            ) ==
                                            group.id,
                                      )
                                      .length ??
                                  0,
                            }),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'rename') {
                                await _renameGroup(
                                  context,
                                  app,
                                  group.id,
                                  group.name,
                                );
                              } else if (value == 'delete') {
                                await _deleteGroup(
                                  context,
                                  app,
                                  group.id,
                                  group.name,
                                );
                              }
                              setSheetState(() {});
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(tr('manager.group.rename')),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(tr('manager.group.delete')),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    nameController.dispose();
  }

  Future<void> _showMoveGroup(
    BuildContext context,
    AppController app,
    String loaderId,
    ModItem mod,
  ) async {
    final current = app.modGroups.groupIdOf(loaderId, mod.pkgId) ?? '';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('manager.group.move')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: '',
              groupValue: current,
              title: Text(tr('manager.group.none')),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            for (final group in app.modGroups.groups)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: group.id,
                groupValue: current,
                title: Text(group.name),
                onChanged: (value) => Navigator.pop(context, value),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await app.assignModToGroup(
      loaderId,
      mod.pkgId,
      selected.isEmpty ? null : selected,
    );
  }

  Future<void> _renameGroup(
    BuildContext context,
    AppController app,
    String id,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('manager.group.rename')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('manager.group.name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await app.renameModGroup(id, name);
    }
  }

  Future<void> _deleteGroup(
    BuildContext context,
    AppController app,
    String id,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('manager.delete.title', {'name': name})),
        content: Text(tr('manager.group.deleteBody')),
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
    if (ok == true) await app.deleteModGroup(id);
  }

  List<T> _filter<T>(List<T> items, String Function(T item) haystack) {
    if (_query.isEmpty) return items;
    return items
        .where((item) => haystack(item).toLowerCase().contains(_query))
        .toList();
  }

  Widget _empty() {
    return EmptyState(
      icon: Icons.widgets_outlined,
      title: tr('manager.empty.title'),
      message: tr('manager.empty.message'),
    );
  }

  Widget _buildStore(BuildContext context) {
    final app = AppScope.of(context);
    final loaders = app.components.loaders
        .where((l) => l.modRepositoryIndexUrl.isNotEmpty)
        .toList();
    if (loaders.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: tr('manager.store.empty'),
        message: tr('manager.store.emptyDesc'),
      );
    }

    final entries = app.storeEntries
        .where(
          (e) => _storeLoaderFilter == null || e.loaderId == _storeLoaderFilter,
        )
        .where((e) {
          final q = _query;
          if (q.isEmpty) return true;
          final m = e.mod;
          return '${m.name} ${m.pkgId} ${m.author} ${m.brieflyDescribe} ${m.description}'
              .toLowerCase()
              .contains(q);
        })
        .toList();

    return Column(
      children: [
        SearchField(
          hint: tr('store.search'),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        if (loaders.length > 1)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: loaders.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final loader = index == 0 ? null : loaders[index - 1];
                final id = loader?.pkgId;
                return ChoiceChip(
                  label: Text(
                    loader == null
                        ? tr('manager.tab.installed')
                        : (loader.name.isEmpty ? loader.pkgId : loader.name),
                  ),
                  selected: _storeLoaderFilter == id,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _storeLoaderFilter = id),
                );
              },
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: app.storeLoading && app.storeEntries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : app.storeError != null && app.storeEntries.isEmpty
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: tr('store.error'),
                  message: app.storeError,
                  action: FilledButton(
                    onPressed: () => app.refreshStore(force: true),
                    child: Text(tr('store.retry')),
                  ),
                )
              : entries.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_outlined,
                  title: tr('store.empty'),
                  message: tr('store.subtitle'),
                )
              : RefreshIndicator(
                  onRefresh: () => app.refreshStore(force: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 96),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _buildStoreCard(context, app, entries[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStoreCard(
    BuildContext context,
    AppController app,
    ModStoreEntry storeEntry,
  ) {
    final mod = storeEntry.mod;
    final installed = (app.components.mods[storeEntry.loaderId] ?? const [])
        .any((m) => m.pkgId == mod.pkgId && m.versionCode >= mod.versionCode);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showStoreDetails(context, storeEntry),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StoreIcon(url: mod.iconUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mod.name.isEmpty ? mod.pkgId : mod.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${mod.author} · v${mod.version}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  installed
                      ? Text(
                          tr('store.installed'),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.primary),
                        )
                      : FilledButton.tonal(
                          onPressed: () =>
                              _downloadStoreEntry(context, app, storeEntry),
                          child: Text(tr('common.download')),
                        ),
                ],
              ),
              if (mod.brieflyDescribe.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  mod.brieflyDescribe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                [
                  mod.pkgId,
                  if (mod.fileSize > 0) formatBytes(mod.fileSize),
                  storeEntry.loaderName,
                ].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadStoreEntry(
    BuildContext context,
    AppController app,
    ModStoreEntry entry,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(entry.mod.name),
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(tr('store.downloading'))),
          ],
        ),
      ),
    );
    final result = await app.downloadAndInstall(entry);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?.success == true
              ? tr('manager.install.success')
              : '${tr('store.downloadFailed')}: ${result?.error ?? ''}',
        ),
      ),
    );
  }

  void _showStoreDetails(BuildContext context, ModStoreEntry entry) {
    final mod = entry.mod;
    _showDetails(
      context,
      title: mod.name,
      pkgId: mod.pkgId,
      version: mod.version,
      versionCode: mod.versionCode,
      author: mod.author,
      description: mod.description.isEmpty
          ? mod.brieflyDescribe
          : mod.description,
      detailsURL: mod.detailsURL,
      extra: [
        _Info(tr('store.source'), entry.loaderName),
        if (mod.fileSize > 0)
          _Info(tr('store.size'), formatBytes(mod.fileSize)),
        if (mod.updateLog.isNotEmpty) _Info('Changelog', mod.updateLog),
      ],
    );
  }

  Future<void> _importPackages(BuildContext context) async {
    final app = AppScope.read(context);
    final paths = await app.pickPackageFiles();
    if (!context.mounted) return;
    if (paths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('manager.import.empty'))));
      return;
    }

    final bundles = await app.inspectBundles(paths);
    if (!mounted) return;
    if (bundles.isNotEmpty) {
      final bundleFiles = bundles.map((b) => b.path).toSet();
      final total =
          bundles.fold<int>(0, (sum, bundle) => sum + bundle.members.length) +
          paths.where((p) => !bundleFiles.contains(p)).length;
      final names = <String>[
        for (final bundle in bundles)
          for (final member in bundle.members) member.split('/').last,
      ];
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('manager.bundle.title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('manager.bundle.body', {'count': total})),
              const SizedBox(height: 10),
              for (final name in names.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (names.length > 8)
                Text(
                  tr('manager.bundle.listMore', {'count': names.length - 8}),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
              child: Text(tr('manager.bundle.continue')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final status = ValueNotifier<String>(tr('manager.install.status.ready'));
    setState(() => _busy = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('manager.install.title')),
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

    final results = await app.installPackages(
      paths,
      onProgress: (phase, {detail}) {
        if (phase == 'bundle' && detail != null && detail.contains('|')) {
          final parts = detail.split('|');
          final counter = parts.first.split('/');
          status.value = tr('manager.install.bundle', {
            'index': counter.first,
            'total': counter.length > 1 ? counter[1] : '?',
            'name': parts.sublist(1).join('|'),
          });
          return;
        }
        status.value = detail == null || detail.isEmpty
            ? tr('manager.install.$phase')
            : '${tr('manager.install.$phase')}: $detail';
      },
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
        title: Text(tr('manager.install.success')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('manager.install.result', {'ok': ok, 'fail': fail})),
            for (final result in results.where((r) => !r.success))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${result.error ?? 'unknown'}\n${tr('manager.install.failDetail')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
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

  Future<void> _confirmDelete(
    BuildContext context,
    AppController app,
    AddonKind kind,
    String pkgId,
    String name, {
    String? loaderId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('manager.delete.title', {'name': name})),
        content: Text(tr('manager.delete.body')),
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
    await app.deleteComponent(kind, pkgId, loaderId: loaderId);
    if (!context.mounted) return;
    setState(() {
      if (loaderId != null) _category = 'loader:$loaderId';
    });
  }

  void _showModuleDetails(BuildContext context, ModuleItem item) {
    _showDetails(
      context,
      title: item.name,
      pkgId: item.pkgId,
      version: item.version,
      versionCode: item.versionCode,
      author: item.author,
      description: item.description.isEmpty
          ? item.brieflyDescribe
          : item.description,
      dependence: item.dependence,
      platforms: item.support.supportedPlatforms,
      detailsURL: item.detailsURL,
    );
  }

  void _showPluginDetails(BuildContext context, PluginItem item) {
    _showDetails(
      context,
      title: item.name,
      pkgId: item.pkgId,
      version: item.version,
      versionCode: item.versionCode,
      author: item.author,
      description: item.description,
    );
  }

  void _showLoaderDetails(
    BuildContext context,
    ModLoaderItem item,
    bool enabled,
  ) {
    _showDetails(
      context,
      title: item.name,
      pkgId: item.pkgId,
      version: item.version,
      versionCode: item.versionCode,
      author: item.author,
      description: item.description.isEmpty
          ? item.brieflyDescribe
          : item.description,
      dependence: item.dependence,
      platforms: item.support.supportedPlatforms,
      extra: [
        _Info(
          tr('manager.loader.enabled'),
          enabled
              ? tr('manager.loader.enabled')
              : tr('manager.loader.disabled'),
        ),
        if (item.modRepositoryIndexUrl.isNotEmpty)
          _Info('Repository', item.modRepositoryIndexUrl),
      ],
    );
  }

  void _showModDetails(
    BuildContext context,
    AppController app,
    ModItem item,
    String loaderId,
  ) {
    final privatePath =
        '${app.rootDir.path}/mods/$loaderId/private/${item.pkgId}';
    final jar = '$privatePath/page/android.jar';
    final hasPage = File(jar).existsSync();

    _showDetails(
      context,
      title: item.name,
      pkgId: item.pkgId,
      version: item.version,
      versionCode: item.versionCode,
      author: item.author,
      description: item.description.isEmpty
          ? item.brieflyDescribe
          : item.description,
      dependence: item.dependence,
      platforms: item.support.supportedPlatforms,
      detailsURL: item.detailsURL,
      extra: [
        if (item.targetGameVersion.isNotEmpty)
          _Info(tr('manager.mod.gameVersion'), item.targetGameVersion),
        if (item.sizeCategory != ModSizeCategory.tiny)
          _Info('Size', item.sizeCategory.name.toUpperCase()),
        if (item.settings.isNotEmpty)
          _Info('Settings', '${item.settings.length}'),
        if (item.conflicts.isNotEmpty)
          _Info(tr('manager.mod.conflict'), item.conflicts.join(', ')),
      ],
      features: item.features.map(_featureLabel).toList(),
      footer: (!hasPage && item.settings.isEmpty)
          ? null
          : Row(
              children: [
                if (hasPage)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final json = await app.openModPage(
                          jarPath: jar,
                          className: item.pageClass,
                          loaderId: loaderId,
                          pkgId: item.pkgId,
                        );
                        if (json == null || !context.mounted) return;
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => JsonUiScreen(
                              jarPath: jar,
                              className: item.pageClass,
                              loaderId: loaderId,
                              pkgId: item.pkgId,
                              initialJson: json,
                              privatePath: privatePath,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.dashboard_rounded),
                      label: Text(tr('mod.page.title')),
                    ),
                  ),
                if (hasPage && item.settings.isNotEmpty)
                  const SizedBox(width: 12),
                if (item.settings.isNotEmpty)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ModSettingsScreen(
                              loaderId: loaderId,
                              mod: item,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(
                        '${tr('mod.settings.title')} (${item.settings.length})',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _featureLabel(ModFeature feature) {
    final key = switch (feature) {
      ModFeature.assistance => 'manager.mod.feature.assistance',
      ModFeature.qualityOfLife => 'manager.mod.feature.quality_of_life',
      ModFeature.utility => 'manager.mod.feature.utility',
      ModFeature.accessibility => 'manager.mod.feature.accessibility',
      ModFeature.visualEnhancement => 'manager.mod.feature.visual_enhancement',
      ModFeature.uiImprovement => 'manager.mod.feature.ui_improvement',
      ModFeature.newContent => 'manager.mod.feature.new_content',
      ModFeature.contentExpansion => 'manager.mod.feature.content_expansion',
      ModFeature.overhaul => 'manager.mod.feature.overhaul',
      ModFeature.mechanicsChange => 'manager.mod.feature.mechanics_change',
      ModFeature.difficultyMod => 'manager.mod.feature.difficulty_mod',
      ModFeature.progressionSystem => 'manager.mod.feature.progression_system',
      ModFeature.adventure => 'manager.mod.feature.adventure',
      ModFeature.building => 'manager.mod.feature.building',
      ModFeature.technology => 'manager.mod.feature.technology',
      ModFeature.magic => 'manager.mod.feature.magic',
      ModFeature.fantasy => 'manager.mod.feature.fantasy',
      ModFeature.sciFi => 'manager.mod.feature.sci_fi',
      ModFeature.realism => 'manager.mod.feature.realism',
      ModFeature.decoration => 'manager.mod.feature.decoration',
      ModFeature.multiplayerEnhanced =>
        'manager.mod.feature.multiplatform_enhanced',
      ModFeature.serverManagement => 'manager.mod.feature.server_management',
      ModFeature.communication => 'manager.mod.feature.communication',
    };
    return tr(key);
  }

  void _showDetails(
    BuildContext context, {
    required String title,
    required String pkgId,
    required String version,
    required int versionCode,
    required String author,
    required String description,
    List<Dependence> dependence = const [],
    List<String> platforms = const [],
    String detailsURL = '',
    List<_Info> extra = const [],
    List<String> features = const [],
    Widget? footer,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                title.isEmpty ? pkgId : title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '$pkgId · v$version ($versionCode)',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (author.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  author,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (platforms.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final p in platforms) MetaChip(label: p)],
                ),
              ],
              if (features.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final feature in features)
                      MetaChip(label: feature, tone: ChipTone.primary),
                  ],
                ),
              ],
              if (extra.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (final info in extra)
                  _DetailRow(label: info.label, value: info.value),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  tr('manager.details'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
              if (dependence.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  tr('manager.dependency'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final dep in dependence)
                  _DetailRow(
                    label: dep.pkgId,
                    value: tr('manager.dependencyVersion', {
                      'version': '>= ${dep.minVersionCode}',
                    }),
                  ),
              ],
              if (detailsURL.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(
                  detailsURL,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: footer),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ModGroupHeader extends StatelessWidget {
  const _ModGroupHeader({
    required this.name,
    required this.count,
    this.onRename,
    this.onDelete,
  });

  final String name;
  final int count;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
      child: Row(
        children: [
          Icon(
            Icons.folder_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$name · $count',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onRename != null || onDelete != null)
            PopupMenuButton<String>(
              tooltip: '',
              iconSize: 18,
              onSelected: (value) {
                if (value == 'rename') onRename?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => [
                if (onRename != null)
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(tr('manager.group.rename')),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(tr('manager.group.delete')),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Category {
  const _Category(this.id, this.label, this.count);

  final String id;
  final String label;
  final int count;
}

class _Info {
  const _Info(this.label, this.value);

  final String label;
  final String value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreIcon extends StatelessWidget {
  const _StoreIcon({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const IconBadge(icon: Icons.extension_rounded);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const IconBadge(icon: Icons.extension_rounded),
      ),
    );
  }
}
