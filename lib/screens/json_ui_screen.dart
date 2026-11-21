import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/i18n.dart';
import '../core/native_bridge.dart';

/// Renders the stable, Compose-free PageNode tree returned by a Mod page.
class JsonUiScreen extends StatefulWidget {
  const JsonUiScreen({
    super.key,
    required this.jarPath,
    required this.className,
    required this.loaderId,
    required this.pkgId,
    required this.initialJson,
    required this.privatePath,
  });

  final String jarPath;
  final String className;
  final String loaderId;
  final String pkgId;
  final String initialJson;
  final String privatePath;

  @override
  State<JsonUiScreen> createState() => _JsonUiScreenState();
}

class _JsonUiScreenState extends State<JsonUiScreen> {
  late String _title;
  late _Node _tree;

  @override
  void initState() {
    super.initState();
    _apply(widget.initialJson);
    NativeBridge.instance.modPageClosed.listen((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _apply(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _title = map['title']?.toString() ?? 'ModPage';
    _tree = _Node.fromJson(map['tree'] as Map<String, dynamic>? ?? const {});
  }

  Future<void> _event(String id, String? value) async {
    final next = await AppScope.read(context).modPageEvent(id, value);
    if (next == null || !mounted) return;
    setState(() => _apply(next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await AppScope.read(context).closeModPage();
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildNode(_tree),
      ),
    );
  }

  Widget _buildNode(_Node node) {
    switch (node.type) {
      case 'column':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final child in node.children) _buildNode(child)],
        );
      case 'row':
        return Row(
          children: [
            for (final child in node.children)
              Expanded(child: _buildNode(child)),
          ],
        );
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            node.str('value', node.str('text')),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      case 'button':
        final id = node.str('id');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: FilledButton(
            onPressed: () {
              final action = node.map('action');
              final url = action?['url']?.toString();
              if (url != null && url.isNotEmpty) {
                NativeBridge.instance.openUrl(url);
              }
              if (id.isNotEmpty) _event(id, null);
            },
            child: Text(node.str('label', tr('mod.page.defaultButton'))),
          ),
        );
      case 'checkbox':
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(node.str('label')),
          value: node.boolValue('value'),
          onChanged: (v) => _event(node.str('id'), v.toString()),
        );
      case 'slider':
        final min = numValue(node.props['min'], 0).toDouble();
        final max = numValue(node.props['max'], 100).toDouble();
        final value = numValue(
          node.props['value'],
          min,
        ).toDouble().clamp(min, max);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(node.str('label')),
          subtitle: Slider(
            value: value,
            min: min,
            max: max == min ? min + 1 : max,
            onChanged: (v) => _event(node.str('id'), v.toString()),
          ),
        );
      case 'input':
        final controller = TextEditingController(text: node.str('value'));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: node.str('label')),
            onSubmitted: (value) => _event(node.str('id'), value),
          ),
        );
      case 'separator':
        return const Divider(height: 16);
      case 'spacer':
        return SizedBox(height: numValue(node.props['height'], 12).toDouble());
      case 'progress':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(
            value: numValue(node.props['value'], 0).toDouble().clamp(0.0, 1.0),
          ),
        );
      case 'collapsing':
        return Card(
          child: ExpansionTile(
            title: Text(node.str('label')),
            children: [for (final c in node.children) _buildNode(c)],
          ),
        );
      case 'image':
        final file = File('${widget.privatePath}/${node.str('path')}');
        if (!file.existsSync()) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Image.file(file, fit: BoxFit.contain),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  static double numValue(dynamic value, double fallback) =>
      value is num ? value.toDouble() : (double.tryParse('$value') ?? fallback);
}

class _Node {
  _Node(this.type, this.props, this.children);

  final String type;
  final Map<String, dynamic> props;
  final List<_Node> children;

  factory _Node.fromJson(Map<String, dynamic> json) => _Node(
    json['type']?.toString() ?? 'text',
    (json['props'] as Map<String, dynamic>? ?? const {})
        .cast<String, dynamic>(),
    ((json['children'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_Node.fromJson)
        .toList(),
  );

  String str(String key, [String fallback = '']) {
    final value = props[key];
    return value == null ? fallback : value.toString();
  }

  bool boolValue(String key) => props[key] == true || props[key] == 'true';

  Map<String, dynamic>? map(String key) =>
      props[key] is Map ? (props[key] as Map).cast<String, dynamic>() : null;
}
