import 'package:flutter/material.dart';

import '../app.dart';
import '../core/i18n.dart';
import '../data/bundled_installer.dart';
import '../widgets/common.dart';
import 'open_source_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _agreed = false;
  final List<bool> _tips = List.filled(4, false);
  bool _installing = false;
  bool _installDone = false;
  int _installIndex = 0;
  String _currentComponent = '';
  List<BundledStep> _steps = const [];

  List<String> get _componentNames => [
    'TEFKernel',
    for (final m in bundledModules) m.label,
  ];

  static const _stepTitleKeys = [
    'onboarding.step.agreement',
    'onboarding.step.tips',
    'onboarding.install.title',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _agreed,
    1 => _tips.every((v) => v),
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.auto_awesome_mosaic_rounded,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TEFManager',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              tr(_stepTitleKeys[_step]),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_step + 1} / ${_stepTitleKeys.length}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / _stepTitleKeys.length,
                      minHeight: 4,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _AgreementStep(
                        agreed: _agreed,
                        onChanged: (v) => setState(() => _agreed = v),
                      ),
                      _TipsStep(
                        values: _tips,
                        onChanged: (index, value) =>
                            setState(() => _tips[index] = value),
                      ),
                      _InstallStep(
                        names: _componentNames,
                        steps: _steps,
                        currentIndex: _installIndex,
                        currentLabel: _currentComponent,
                        installing: _installing,
                        done: _installDone,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(
                    children: [
                      if (_step > 0)
                        TextButton(
                          onPressed: _back,
                          child: Text(tr('onboarding.tips.back')),
                        ),
                      const Spacer(),
                      if (_step < _stepTitleKeys.length - 1)
                        FilledButton(
                          onPressed: _canContinue ? _next : null,
                          child: Text(tr('onboarding.next')),
                        )
                      else if (!_installDone)
                        FilledButton(
                          onPressed: _installing ? null : _install,
                          child: Text(
                            _installing
                                ? tr('onboarding.install.installingButton')
                                : tr('onboarding.install.button'),
                          ),
                        )
                      else
                        FilledButton(
                          onPressed: _finish,
                          child: Text(tr('onboarding.finish')),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _next() {
    if (!_canContinue) return;
    setState(() => _step++);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _install() async {
    if (_installing) return;
    setState(() {
      _installing = true;
      _installDone = false;
      _steps = const [];
      _installIndex = 0;
      _currentComponent = _componentNames.first;
    });
    final app = AppScope.read(context);
    final steps = await app.installBundledComponents(
      onProgress: (label, index, total) {
        if (!mounted) return;
        setState(() {
          _installIndex = index;
          _currentComponent = label;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _installing = false;
      _installDone = true;
      _installIndex = _componentNames.length;
    });
  }

  Future<void> _finish() async {
    await AppScope.read(context).completeOnboarding();
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Card(
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}

class _AgreementStep extends StatelessWidget {
  const _AgreementStep({required this.agreed, required this.onChanged});

  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('onboarding.agreement.title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            tr('onboarding.agreement.subtitle'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                child: Text(
                  tr('onboarding.agreement.text'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.55),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: agreed,
            onChanged: (value) => onChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr('onboarding.agreement.check')),
          ),
        ],
      ),
    );
  }
}

class _TipsStep extends StatelessWidget {
  const _TipsStep({required this.values, required this.onChanged});

  final List<bool> values;
  final void Function(int index, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('onboarding.tips.title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            tr('onboarding.tips.subtitle'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: values.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => CheckboxListTile(
                value: values[index],
                onChanged: (value) => onChanged(index, value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  tr('onboarding.tips.item${index + 1}'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({
    required this.names,
    required this.steps,
    required this.currentIndex,
    required this.currentLabel,
    required this.installing,
    required this.done,
  });

  final List<String> names;
  final List<BundledStep> steps;
  final int currentIndex;
  final String currentLabel;
  final bool installing;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = names.length;
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            done
                ? tr('onboarding.install.completeTitle')
                : tr('onboarding.install.title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            done
                ? tr('onboarding.install.complete')
                : (installing
                      ? tr('onboarding.install.installing', {
                          'component': currentLabel,
                        })
                      : tr('onboarding.install.start')),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0
                  ? 0
                  : (done ? total : currentIndex).clamp(0, total) / total,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: total,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final step = index < steps.length ? steps[index] : null;
                final isCurrent = installing && index == currentIndex;
                IconData icon;
                Color color;
                if (step != null) {
                  if (step.success) {
                    icon = step.skipped
                        ? Icons.skip_next_rounded
                        : Icons.check_circle_rounded;
                    color = scheme.primary;
                  } else {
                    icon = Icons.error_outline_rounded;
                    color = scheme.error;
                  }
                } else if (isCurrent) {
                  icon = Icons.downloading_rounded;
                  color = scheme.primary;
                } else {
                  icon = Icons.radio_button_unchecked_rounded;
                  color = scheme.onSurfaceVariant;
                }
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: color),
                  title: Text(names[index]),
                  subtitle: step != null && !step.success
                      ? Text(
                          step.error ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: scheme.error),
                        )
                      : null,
                  trailing: step == null
                      ? null
                      : MetaChip(
                          label: step.skipped
                              ? tr('onboarding.install.latest')
                              : (step.success
                                    ? tr('onboarding.install.statusCompleted')
                                    : tr('onboarding.install.statusFailed')),
                          tone: step.success
                              ? ChipTone.success
                              : ChipTone.warning,
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OpenSourceScreen(),
                ),
              ),
              icon: const Icon(Icons.article_outlined, size: 18),
              label: Text(tr('settings.about.openSource')),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('onboarding.android.tips4'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
