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
          final visibleBrightness =
              AppTheme.resolveBrightness(config.themeMode, systemBrightness);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'TEFManager',
            themeMode: visibleBrightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
            theme: AppTheme.light(seed),
            darkTheme: AppTheme.dark(seed),
            builder: (context, child) {
              final scale = config.fontSizeScale.clamp(0.5, 2.0);
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(textScaler: TextScaler.linear(scale)),
                child: child ?? const SizedBox.shrink(),
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
