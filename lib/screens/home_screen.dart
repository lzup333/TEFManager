import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../controllers/app_controller.dart';
import '../core/i18n.dart';
import '../core/native_bridge.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final games = app.games;
    final selected = app.selectedGame;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const _BrandMark(),
            const SizedBox(width: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showModeDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TEFManager'),
                    Row(
                      children: [
                        Text(
                          app.moduleActive ? tr('mode.root') : tr('mode.external'),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('refresh'),
            onPressed: app.busy ? null : app.refreshGames,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: games.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddGame(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('home.game.add')),
            ),
      body: games.isEmpty
          ? EmptyState(
              icon: Icons.sports_esports_outlined,
              title: tr('home.game.empty'),
              message: tr('home.game.prompt'),
              action: FilledButton.icon(
                onPressed: () => _showAddGame(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(tr('home.game.add')),
              ),
            )
          : Column(
              children: [
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _SelectedGameCard(game: selected),
                  ),
                SectionHeader(
                  title: tr('home.game.title'),
                  subtitle:
                      '${games.length} ${tr('home.game.count')}'.trim(),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: games.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final game = games[index];
                      return _GameTile(
                        game: game,
                        selected: game.hash == selected?.hash,
                        onTap: () => app.selectGame(game),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showAddGame(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _AddGameDialog(),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.auto_awesome_mosaic_rounded,
        color: scheme.onPrimaryContainer,
        size: 22,
      ),
    );
  }
}

class _SelectedGameCard extends StatelessWidget {
  const _SelectedGameCard({required this.game});

  final GameItem game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports_rounded,
                    color: scheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName(game),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${game.version}  ·  ${game.apkPackName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                MetaChip(
                  label: 'v${game.versionCode}',
                  tone: ChipTone.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimaryContainer,
                  foregroundColor: scheme.primaryContainer,
                ),
                onPressed: () => _launchGame(context),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(tr('home.game.play')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _launchGame(BuildContext context) async {
  final app = AppScope.read(context);
  if (app.moduleActive) {
    final root = await app.hasRoot();
    if (!context.mounted) return;
    if (!root) {
      await _showRootRequired(context);
      return;
    }
  }
  final ok = await app.launchSelected();
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('home.game.launchFailed'))),
    );
  }
}

Future<void> _showRootRequired(BuildContext context) async {
  final app = AppScope.read(context);
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(tr('root.required.title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('root.required.body')),
              const SizedBox(height: 12),
              _RootStatus(app: app),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('close')),
            ),
            FilledButton(
              onPressed: () async {
                final root = await app.hasRoot();
                if (!context.mounted) return;
                if (root) {
                  Navigator.pop(context);
                  await _launchGame(context);
                } else {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('root.denied'))),
                  );
                }
              },
              child: Text(tr('root.required.retry')),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _showModeDialog(BuildContext context) async {
  final app = AppScope.read(context);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('mode.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            app.moduleActive ? tr('mode.root') : tr('mode.external'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            app.moduleActive ? tr('mode.rootDesc') : tr('mode.externalDesc'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (app.moduleActive) ...[
            const SizedBox(height: 12),
            _RootStatus(app: app),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('close')),
        ),
      ],
    ),
  );
}

class _RootStatus extends StatefulWidget {
  const _RootStatus({required this.app});

  final AppController app;

  @override
  State<_RootStatus> createState() => _RootStatusState();
}

class _RootStatusState extends State<_RootStatus> {
  bool? _root;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final root = await widget.app.hasRoot();
    if (mounted) setState(() => _root = root);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final root = _root;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _check,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (root == null)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                root ? Icons.verified_rounded : Icons.error_outline_rounded,
                size: 18,
                color: root ? scheme.primary : scheme.error,
              ),
            const SizedBox(width: 8),
            Text(
              root == null
                  ? tr('root.check')
                  : (root ? tr('root.available') : tr('root.denied')),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.game,
    required this.selected,
    required this.onTap,
  });

  final GameItem game;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              IconBadge(
                icon: Icons.videogame_asset_rounded,
                size: 42,
                color: selected ? scheme.primary : scheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName(game),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      game.apkPackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(game.version,
                      style: Theme.of(context).textTheme.labelMedium),
                  Text(
                    game.hash.isEmpty ? '—' : game.hash.substring(0, 8),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String displayName(GameItem game) {
  if (game.apkPackName.endsWith('Paid')) return 'Terraria (Paid)';
  return 'Terraria';
}

class _AddGameDialog extends StatefulWidget {
  const _AddGameDialog();

  @override
  State<_AddGameDialog> createState() => _AddGameDialogState();
}

class _AddGameDialogState extends State<_AddGameDialog> {
  PatchOption _option = PatchOption.appComponentFactory;
  bool _initialized = false;
  bool _patching = false;
  String? _phaseKey;
  String? _error;
  StreamSubscription<String>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!_initialized) {
      _initialized = true;
      _option = app.sdk >= 28
          ? PatchOption.appComponentFactory
          : PatchOption.application;
    }
    final scheme = Theme.of(context).colorScheme;
    final recommended =
        app.sdk >= 28 ? PatchOption.appComponentFactory : PatchOption.application;
    final factoryWarning =
        _option == PatchOption.appComponentFactory && app.sdk < 28;

    return PopScope(
      canPop: !_patching,
      child: AlertDialog(
        title: Text(_patching ? tr('home.patching') : tr('home.add.title')),
        content: _patching
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LinearProgressIndicator(minHeight: 5),
                  const SizedBox(height: 14),
                  Text(
                    tr(_phaseKey ?? 'home.patching'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('home.patch.hint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('home.add.subtitle')),
                    const SizedBox(height: 14),
                    _StepLine(number: 1, text: tr('home.add.step.pick')),
                    _StepLine(number: 2, text: tr('home.add.step.patch')),
                    _StepLine(number: 3, text: tr('home.add.step.install')),
                    const SizedBox(height: 8),
                    Text(
                      tr('home.patch.entrance'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    RadioListTile<PatchOption>(
                      contentPadding: EdgeInsets.zero,
                      value: PatchOption.application,
                      groupValue: _option,
                      onChanged: (value) =>
                          setState(() => _option = value ?? _option),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(tr('home.patch.option.application')),
                          ),
                          if (recommended == PatchOption.application)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: MetaChip(
                                label: tr('home.patch.recommend'),
                                tone: ChipTone.success,
                              ),
                            ),
                        ],
                      ),
                    ),
                    RadioListTile<PatchOption>(
                      contentPadding: EdgeInsets.zero,
                      value: PatchOption.appComponentFactory,
                      groupValue: _option,
                      onChanged: (value) =>
                          setState(() => _option = value ?? _option),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(tr('home.patch.option.factory')),
                          ),
                          if (recommended == PatchOption.appComponentFactory)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: MetaChip(
                                label: tr('home.patch.recommend'),
                                tone: ChipTone.success,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (factoryWarning)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          tr('home.patch.entranceWorng', {'SDK': app.sdk}),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                              ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('home.add.hint'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
        actions: _patching
            ? const []
            : [
                TextButton(
                  onPressed: () {
                    _subscription?.cancel();
                    Navigator.pop(context);
                  },
                  child: Text(tr('cancel')),
                ),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.build_circle_outlined),
                  label: Text(tr('home.patch.pick')),
                ),
              ],
      ),
    );
  }

  Future<void> _start() async {
    final app = AppScope.read(context);
    final paths = await app.pickApkFile();
    if (!mounted || paths.isEmpty) return;
    final path = paths.first;
    final originalName = path.split('/').last;
    setState(() {
      _patching = true;
      _error = null;
      _phaseKey = null;
    });
    _subscription = app.patchProgress.listen((phase) {
      if (mounted) setState(() => _phaseKey = phase);
    });

    final result = await app.patchApk(path, _option);
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _patching = false;
        _error = '${tr('home.patch.failed')}: ${result.error ?? ''}';
      });
      return;
    }

    final stem = originalName.toLowerCase().endsWith('.apk')
        ? originalName.substring(0, originalName.length - 4)
        : originalName;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final saved = await app.exportFile(path, '${stem}_patched_$stamp.apk');
    if (!mounted) return;

    if (saved) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('home.patch.saved'))),
      );
      await app.refreshGames();
    } else {
      setState(() {
        _patching = false;
        _error = tr('home.patch.cancelled');
      });
    }
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$number',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
