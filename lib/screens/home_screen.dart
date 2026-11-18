import 'package:flutter/material.dart';

import '../app.dart';
import '../core/i18n.dart';
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TEFManager'),
                Text(
                  app.moduleActive ? 'Root / Xposed 模式' : '外部模式',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
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
    final app = AppScope.of(context);
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
                onPressed: () async {
                  final ok = await app.launchSelected();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('home.game.launchFailed'))),
                    );
                  }
                },
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

class _AddGameDialog extends StatelessWidget {
  const _AddGameDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(tr('home.add.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('home.add.subtitle')),
          const SizedBox(height: 16),
          _Step(number: 1, text: tr('home.add.step.pick')),
          _Step(number: 2, text: tr('home.add.step.patch')),
          _Step(number: 3, text: tr('home.add.step.install')),
          const SizedBox(height: 12),
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('home.add.notReady'))),
            );
          },
          child: Text(tr('home.add.chooseApk')),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
