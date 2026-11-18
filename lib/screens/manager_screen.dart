import 'package:flutter/material.dart';

import '../app.dart';
import '../controllers/app_controller.dart';
import '../core/i18n.dart';
import '../widgets/common.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  int _tab = 0;
  int _kind = 0;

  static const _kinds = ['module', 'plugin', 'loader', 'mod'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('manager.title')),
        actions: [
          IconButton(
            tooltip: tr('manager.add'),
            onPressed: () => _showImportHint(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
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
            child: _tab == 0 ? _buildInstalled(context, app) : _buildStore(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalled(BuildContext context, AppController app) {
    return Column(
      children: [
        SearchField(hint: tr('manager.searchMod')),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _kinds.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = _kind == index;
              return ChoiceChip(
                label: Text(tr('manager.kind.${_kinds[index]}')),
                selected: selected,
                onSelected: (_) => setState(() => _kind = index),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: EmptyState(
            icon: Icons.widgets_outlined,
            title: tr('manager.empty.title'),
            message: tr('manager.empty.message'),
            action: FilledButton.icon(
              onPressed: () => _showImportHint(context),
              icon: const Icon(Icons.file_open_outlined),
              label: Text(tr('manager.add')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStore(BuildContext context) {
    return const EmptyState(
      icon: Icons.storefront_outlined,
      title: '没有可用的模组仓库',
      message: '启用一个带仓库地址的 ModLoader 后即可浏览',
    );
  }

  Future<void> _showImportHint(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('manager.add')),
        content: Text(tr('manager.add.desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('close')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('manager.add.choose')),
          ),
        ],
      ),
    );
  }
}
