import 'package:flutter/material.dart';

import '../core/i18n.dart';
import 'home_screen.dart';
import 'manager_screen.dart';
import 'resources_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = [
    _Destination(
      labelKey: 'home.title',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _Destination(
      labelKey: 'manager.title',
      icon: Icons.widgets_outlined,
      selectedIcon: Icons.widgets_rounded,
    ),
    _Destination(
      labelKey: 'resource.title',
      icon: Icons.palette_outlined,
      selectedIcon: Icons.palette_rounded,
    ),
    _Destination(
      labelKey: 'settings.title',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  final _pages = const [
    HomeScreen(),
    ManagerScreen(),
    ResourcesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final body = IndexedStack(index: _index, children: _pages);

        if (!wide) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: tr(d.labelKey),
                    tooltip: tr(d.labelKey),
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: _LogoMark(size: 40),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(tr(d.labelKey)),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _Destination {
  const _Destination({
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
  });

  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.auto_awesome_mosaic_rounded,
        size: size * 0.55,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}
