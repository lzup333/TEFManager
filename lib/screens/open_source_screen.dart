import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/i18n.dart';
import '../core/native_bridge.dart';
import '../widgets/common.dart';

/// Visible open-source declaration: project license plus the third-party
/// components shipped in this app.
class OpenSourceScreen extends StatelessWidget {
  const OpenSourceScreen({super.key});

  static const _packages = [
    _Package(
      name: 'Flutter / Dart',
      license: 'BSD-3-Clause',
      description: 'UI framework and language runtime',
      url: 'https://flutter.dev',
    ),
    _Package(
      name: 'path_provider',
      license: 'BSD-3-Clause',
      description: 'Platform data directories',
      url: 'https://pub.dev/packages/path_provider',
    ),
    _Package(
      name: 'archive',
      license: 'MIT',
      description: 'ZIP / TEF package handling',
      url: 'https://pub.dev/packages/archive',
    ),
    _Package(
      name: 'http',
      license: 'BSD-3-Clause',
      description: 'Repository & update downloads',
      url: 'https://pub.dev/packages/http',
    ),
    _Package(
      name: 'crypto',
      license: 'BSD-3-Clause',
      description: 'Hashes for package verification',
      url: 'https://pub.dev/packages/crypto',
    ),
    _Package(
      name: 'TEFKernel',
      license: 'AGPL-3.0',
      description: 'Terraria mod kernel loaded by the game',
      url: 'https://github.com/eternalfuture-e38299/TEFKernel',
    ),
    _Package(
      name: 'TEFLoader',
      license: 'AGPL-3.0',
      description: 'Bootstrap injected into the patched game',
      url: 'https://github.com/eternalfuture-e38299/TEFKernel',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('oss.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(
            title: tr('oss.project'),
            subtitle: tr('oss.projectDesc'),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'TEFManager',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const MetaChip(label: 'AGPL-3.0', tone: ChipTone.primary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('oss.projectText'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            NativeBridge.instance.openUrl(AppInfo.githubUrl),
                        icon: const Icon(Icons.code_rounded, size: 18),
                        label: const Text('GitHub'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => NativeBridge.instance.openUrl(
                          'https://www.gnu.org/licenses/agpl-3.0.html',
                        ),
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('AGPL-3.0'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(
            title: tr('oss.thirdParty'),
            subtitle: tr('oss.thirdPartyDesc'),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < _packages.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: Text(_packages[i].name),
                    subtitle: Text(
                      '${_packages[i].license} · ${_packages[i].description}',
                    ),
                    trailing: IconButton(
                      tooltip: _packages[i].url,
                      onPressed: () =>
                          NativeBridge.instance.openUrl(_packages[i].url),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FilledButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'TEFManager',
                applicationVersion:
                    '${AppInfo.versionName} (${AppInfo.versionCode})',
                applicationLegalese:
                    'Copyright © 2026 eternalfuture-e38299 · AGPL-3.0',
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(tr('oss.viewLicenses')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              tr('oss.notice'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Package {
  const _Package({
    required this.name,
    required this.license,
    required this.description,
    required this.url,
  });

  final String name;
  final String license;
  final String description;
  final String url;
}
