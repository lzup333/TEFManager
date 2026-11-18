import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../widgets/common.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  int _type = 0;

  static const _types = [
    _PackType('resource.language.title', Icons.translate_rounded),
    _PackType('resource.languagePatch', Icons.spellcheck_rounded),
    _PackType('resource.texture', Icons.image_outlined),
    _PackType('resource.font.title', Icons.font_download_outlined),
    _PackType('resource.audio.title', Icons.music_note_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final label = tr(_types[_type].labelKey);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('resource.title')),
        actions: [
          IconButton(
            tooltip: tr('resource.add', {'packType': label}),
            onPressed: () => _showImportHint(context, label),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImportHint(context, label),
        icon: const Icon(Icons.unarchive_outlined),
        label: Text(tr('resource.add', {'packType': label})),
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
                final item = _types[index];
                return ChoiceChip(
                  avatar: Icon(item.icon, size: 16),
                  label: Text(tr(item.labelKey)),
                  selected: _type == index,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _type = index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('resource.prompt'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: EmptyState(
              icon: _types[_type].icon,
              title: tr('resource.empty', {'packType': label}),
              message: tr('resource.emptyAction', {'packType': label}),
              action: OutlinedButton.icon(
                onPressed: () => _showImportHint(context, label),
                icon: const Icon(Icons.file_open_outlined),
                label: Text(tr('resource.add', {'packType': label})),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportHint(BuildContext context, String packType) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('resource.install.title')),
        content: Text(
          tr('resource.add', {'packType': packType}),
          style: Theme.of(context).textTheme.bodyMedium,
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
}

class _PackType {
  const _PackType(this.labelKey, this.icon);

  final String labelKey;
  final IconData icon;
}
