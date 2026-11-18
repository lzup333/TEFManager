import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../core/i18n.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class ModSettingsScreen extends StatefulWidget {
  const ModSettingsScreen({
    super.key,
    required this.loaderId,
    required this.mod,
  });

  final String loaderId;
  final ModItem mod;

  @override
  State<ModSettingsScreen> createState() => _ModSettingsScreenState();
}

class _ModSettingsScreenState extends State<ModSettingsScreen> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    final stored = await app.loadModSettings(widget.loaderId, widget.mod.pkgId);
    if (!mounted) return;
    setState(() {
      for (final setting in widget.mod.settings) {
        _values[setting.key] =
            stored.containsKey(setting.key) ? stored[setting.key] : setting.defaultValue;
        if (setting.type == ModSettingType.string) {
          _controllers[setting.key] =
              TextEditingController(text: '${_values[setting.key] ?? ''}');
        }
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    for (final entry in _controllers.entries) {
      _values[entry.key] = entry.value.text;
    }
    final app = AppScope.read(context);
    await app.saveModSettings(widget.loaderId, widget.mod.pkgId, _values);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('mod.settings.saved'))),
    );
  }

  void _resetDefaults() {
    setState(() {
      for (final setting in widget.mod.settings) {
        _values[setting.key] = setting.defaultValue;
        final controller = _controllers[setting.key];
        if (controller != null) {
          controller.text = '${setting.defaultValue ?? ''}';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<ModSetting>>{};
    for (final setting in widget.mod.settings) {
      sections.putIfAbsent(setting.section, () => []).add(setting);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mod.name.isEmpty ? widget.mod.pkgId : widget.mod.name),
        actions: [
          IconButton(
            tooltip: tr('mod.settings.save'),
            onPressed: _loading || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _resetDefaults(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(tr('mod.settings.reset')),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    tr('mod.settings.subtitle'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                for (final entry in sections.entries) ...[
                  if (entry.key.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                      child: Text(
                        entry.key,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < entry.value.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          _buildSetting(entry.value[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSetting(ModSetting setting) {
    final value = _values[setting.key];
    final subtitle =
        setting.description.isEmpty ? null : setting.description;
    switch (setting.type) {
      case ModSettingType.switchType:
        return SwitchListTile(
          title: Text(setting.title),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: value == true,
          onChanged: (v) => setState(() => _values[setting.key] = v),
        );
      case ModSettingType.integer:
        final min = setting.min;
        final max = setting.max > min ? setting.max : null;
        final current = value is num ? value.toInt() : int.tryParse('$value') ?? min;
        if (max == null) {
          return ListTile(
            title: Text(setting.title),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: SizedBox(
              width: 96,
              child: TextFormField(
                initialValue: '$current',
                textAlign: TextAlign.end,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (text) => _values[setting.key] = int.tryParse(text) ?? current,
              ),
            ),
          );
        }
        final step = setting.step <= 0 ? 1 : setting.step;
        final divisions = ((max - min) ~/ step).clamp(1, 200);
        final clamped = current.clamp(min, max);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(setting.title),
              subtitle: subtitle == null ? null : Text(subtitle),
              trailing: MetaChip(
                label: '$clamped${setting.unit == '×' ? '' : setting.unit}',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Slider(
                value: clamped.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: divisions,
                label: '$clamped',
                onChanged: (v) => setState(
                  () => _values[setting.key] = v.round(),
                ),
              ),
            ),
          ],
        );
      case ModSettingType.choice:
        final options = setting.options;
        final current = '${value ?? ''}';
        final valid = options.any((o) => o.value == current) || options.isEmpty;
        return ListTile(
          title: Text(setting.title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: DropdownButton<String>(
            value: valid ? current : null,
            underline: const SizedBox.shrink(),
            hint: const Text('—'),
            onChanged: (v) {
              if (v != null) setState(() => _values[setting.key] = v);
            },
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label.isNotEmpty ? option.label : option.value),
                ),
            ],
          ),
        );
      case ModSettingType.string:
        return ListTile(
          title: Text(setting.title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: SizedBox(
            width: 160,
            child: TextField(
              controller: _controllers[setting.key],
              textAlign: TextAlign.end,
              decoration: const InputDecoration(isDense: true),
              onChanged: (text) => _values[setting.key] = text,
            ),
          ),
        );
    }
  }
}
