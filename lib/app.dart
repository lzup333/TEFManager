import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/i18n.dart';
import '../theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }

  static AppController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}

class TefManagerApp extends StatelessWidget {
  const TefManagerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final config = controller.config;
          final seed = Color(config.themeSeedColor);
          final systemBrightness =
              WidgetsBinding.instance.platformDispatcher.platformBrightness;
          final visibleBrightness = AppTheme.resolveBrightness(
            config.themeMode,
            systemBrightness,
          );
          final backgroundPath = controller.backgroundImagePath;
          final hasBackground = backgroundPath.isNotEmpty;

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'TEFManager',
            themeMode: visibleBrightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
            theme: AppTheme.light(seed, transparentScaffold: hasBackground),
            darkTheme: AppTheme.dark(seed, transparentScaffold: hasBackground),
            builder: (context, child) {
              if (controller.uiHidden) {
                return const _EasterHiddenOverlay();
              }
              final scale = config.fontSizeScale.clamp(0.5, 2.0);
              final media = MediaQuery.of(context);
              final content = MediaQuery(
                data: media.copyWith(textScaler: TextScaler.linear(scale)),
                child: child ?? const SizedBox.shrink(),
              );
              if (!hasBackground) return content;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(backgroundPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                  ColoredBox(
                    color: Colors.black.withValues(
                      alpha: controller.config.backgroundDim,
                    ),
                  ),
                  Positioned.fill(child: content),
                ],
              );
            },
            home: !controller.ready
                ? const _BootScreen()
                : (config.initialized
                      ? const AppShell()
                      : const OnboardingScreen()),
          );
        },
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(tr('loading') == 'loading' ? '正在启动…' : tr('loading')),
          ],
        ),
      ),
    );
  }
}

class _EasterHiddenOverlay extends StatefulWidget {
  const _EasterHiddenOverlay();

  @override
  State<_EasterHiddenOverlay> createState() => _EasterHiddenOverlayState();
}

class _EasterHiddenOverlayState extends State<_EasterHiddenOverlay> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _taps++;
          if (_taps >= 3) {
            AppScope.read(context).setUiHidden(false);
          } else if (mounted) {
            setState(() {});
          }
        },
        child: Center(
          child: _taps > 0
              ? Text(
                  '${3 - _taps}',
                  style: const TextStyle(color: Colors.white12, fontSize: 72),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
