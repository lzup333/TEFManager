import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_info.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../widgets/common.dart';
import 'open_source_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final config = app.config;

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(title: tr('settings.general.title')),
          SettingCard(
            children: [
              SettingSwitch(
                title: tr('settings.general.update'),
                subtitle: tr('settings.general.updateDec'),
                value: config.autoUpdate,
                onChanged: (value) =>
                    app.updateConfig((c) => c.autoUpdate = value),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                title: Text(tr('settings.general.language')),
                subtitle: Text(tr('settings.general.languageDec')),
                trailing: DropdownButton<AppLanguage>(
                  value: config.language,
                  underline: const SizedBox.shrink(),
                  onChanged: (value) {
                    if (value != null) app.setLanguage(value);
                  },
                  items: [
                    for (final lang in AppLanguage.values)
                      DropdownMenuItem(
                        value: lang,
                        child: Text(
                          lang == AppLanguage.system
                              ? tr('settings.followSystem')
                              : lang.label,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SectionHeader(title: tr('settings.appearance.title')),
          SettingCard(
            children: [
              ListTile(
                title: Text(tr('settings.appearance.theme')),
                subtitle: Text(tr('settings.appearance.themeDec')),
                trailing: DropdownButton<AppThemeMode>(
                  value: config.themeMode,
                  underline: const SizedBox.shrink(),
                  onChanged: (value) {
                    if (value != null) app.setThemeMode(value);
                  },
                  items: [
                    for (final mode in AppThemeMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(tr(mode.labelKey)),
                      ),
                  ],
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              SettingSwitch(
                title: tr('settings.appearance.dynamicColor'),
                subtitle: tr('settings.appearance.dynamicColorDec'),
                value: config.dynamicColor,
                onChanged: app.setDynamicColor,
              ),
              const Divider(indent: 16, endIndent: 16),
              _SeedColorTile(color: Color(config.themeSeedColor)),
              const Divider(indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('settings.appearance.fontSize'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            tr('settings.appearance.fontSizeDec'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    MetaChip(
                      label: '${(config.fontSizeScale * 100).round()}%',
                      tone: ChipTone.primary,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Slider(
                  value: config.fontSizeScale.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  label: '${(config.fontSizeScale * 100).round()}%',
                  onChanged: app.setFontScale,
                ),
              ),
            ],
          ),
          SectionHeader(title: tr('settings.advanced.title')),
          SettingCard(
            children: [
              SettingSwitch(
                title: tr('settings.advanced.kernelLog'),
                subtitle: tr('settings.advanced.kernelLogDec'),
                value: config.kernelLogEnabled,
                onChanged: (value) =>
                    app.updateConfig((c) => c.kernelLogEnabled = value),
              ),
              SettingSwitch(
                title: tr('settings.advanced.softwareLog'),
                subtitle: tr('settings.advanced.softwareLogDec'),
                value: config.softwareLogEnabled,
                onChanged: (value) =>
                    app.updateConfig((c) => c.softwareLogEnabled = value),
              ),
              const Divider(indent: 16, endIndent: 16),
              SettingSwitch(
                title: tr('settings.advanced.autoCleanLogs'),
                subtitle: tr('settings.advanced.autoCleanLogsDec'),
                value: config.autoCleanLogs,
                onChanged: (value) =>
                    app.updateConfig((c) => c.autoCleanLogs = value),
              ),
              _NumberTile(
                title: tr('settings.advanced.maxAppLogFiles'),
                subtitle: tr('settings.advanced.maxAppLogFilesDec'),
                value: config.maxAppLogFiles,
                min: 1,
                max: 50,
                onChanged: (value) =>
                    app.updateConfig((c) => c.maxAppLogFiles = value),
              ),
              _NumberTile(
                title: tr('settings.advanced.maxAppLogSize'),
                subtitle: tr('settings.advanced.maxAppLogSizeDec'),
                value: config.maxAppLogSizeMB,
                min: 1,
                max: 100,
                onChanged: (value) =>
                    app.updateConfig((c) => c.maxAppLogSizeMB = value),
              ),
            ],
          ),
          SectionHeader(title: tr('settings.about.title')),
          SettingCard(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('TEFManager'),
                subtitle: Text(
                  tr('app.version', {
                    'version': AppInfo.versionName,
                    'versionCode': AppInfo.versionCode,
                  }),
                ),
                trailing: const MetaChip(
                  label: 'Android',
                  tone: ChipTone.success,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.memory_rounded),
                title: Text(tr('settings.about.kernelVersion')),
                subtitle: Text(config.kernelVersion),
              ),
              ListTile(
                leading: const Icon(Icons.devices_rounded),
                title: Text(tr('settings.about.supportPlatforms')),
                subtitle: const Text('Android (ARM64 / ARM / x86_64 / x86)'),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(tr('settings.about.developer')),
                subtitle: Text(tr('settings.about.developerName')),
              ),
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('GitHub'),
                subtitle: Text(AppInfo.githubLabel),
                onTap: () => _notReady(context),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(tr('settings.about.license')),
                subtitle: Text(AppInfo.license),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(tr('settings.about.openSource')),
                subtitle: Text(tr('oss.projectDesc')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OpenSourceScreen(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _checkUpdates(context),
                        icon: const Icon(Icons.system_update_alt_rounded),
                        label: Text(tr('settings.about.checkUpdate')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _importKernel(context),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(tr('settings.about.import')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _reinstall(context),
                        icon: const Icon(Icons.build_circle_outlined),
                        label: Text(tr('settings.about.reinstall')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              tr('settings.about.copyright'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importKernel(BuildContext context) async {
    final app = AppScope.read(context);
    final paths = await app.pickKernelFile();
    if (!context.mounted) return;
    if (paths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('manager.import.empty'))));
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(tr('settings.about.importing'))),
          ],
        ),
      ),
    );
    String? version;
    String? error;
    try {
      version = await app.importKernel(paths.first);
    } catch (e) {
      error = '$e';
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          version != null
              ? tr('kernel.import.success', {'version': version})
              : '${tr('kernel.import.failed')}: ${error ?? ''}',
        ),
      ),
    );
  }

  Future<void> _checkUpdates(BuildContext context) async {
    final app = AppScope.read(context);
    final candidates = await app.checkUpdates();
    if (!context.mounted) return;
    if (candidates == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('update.failed'))));
      return;
    }
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('update.none'))));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('update.title')),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = candidates[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.title),
                subtitle: Text(
                  tr('update.current', {'version': item.currentVersion}) +
                      '  →  ' +
                      tr('update.latest', {'version': item.latestVersion}),
                ),
                trailing: FilledButton(
                  onPressed: () async {
                    showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        content: Row(
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: Text(tr('update.downloading'))),
                          ],
                        ),
                      ),
                    );
                    final error = await app.applyUpdate(item);
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop();
                    if (error != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error)));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('update.done'))),
                      );
                    }
                  },
                  child: Text(tr('update.apply')),
                ),
              );
            },
          ),
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

  Future<void> _reinstall(BuildContext context) async {
    final app = AppScope.read(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(tr('settings.about.reinstalling'))),
          ],
        ),
      ),
    );
    final steps = await app.installBundledComponents();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final failed = steps.where((s) => !s.success).toList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty
              ? tr('onboarding.install.complete')
              : failed.map((s) => '${s.name}: ${s.error}').join('\n'),
        ),
      ),
    );
  }

  void _notReady(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('home.add.notReady'))));
  }
}

class _SeedColorTile extends StatelessWidget {
  const _SeedColorTile({required this.color});

  final Color color;

  static const _presets = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListTile(
      title: Text(tr('settings.appearance.themeColor')),
      subtitle: Text(tr('settings.appearance.themeColorDec')),
      trailing: Wrap(
        spacing: 8,
        children: [
          for (final preset in _presets)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => app.setSeedColor(preset.toARGB32()),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: preset,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: preset.toARGB32() == color.toARGB32()
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
