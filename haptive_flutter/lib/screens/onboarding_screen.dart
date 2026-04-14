import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/habit_api.dart';
import '../state/habit_store.dart';
import '../theme/haptive_theme.dart';
import '../utils/currency_format.dart';
import 'app_shell.dart';

/// Comfortable tap targets (≈52px height) for primary actions and segment controls.
const double _kOnboardingButtonHeight = 52;

/// Typography-led setup flow — matches [PulseTypographyHome] (minimal chrome, no bento cards).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _reasonCtrl = TextEditingController();
  final _spendCtrl = TextEditingController(text: '12.5');
  final _hoursCtrl = TextEditingController(text: '1.5');
  int _step = 0;
  String _goalType = 'quit';
  int _milestoneDays = 30;
  String _currencyChoice = 'auto';
  final Set<String> _triggerProfile = {};

  static const _stepCount = 5;

  static const _triggerOptions = [
    'Stress',
    'Boredom',
    'Social',
    'Lonely',
    'Late night',
    'After meals',
  ];

  static const _headlines = [
    'Your goal',
    'Why now?',
    'First milestone',
    'Currency',
    'Daily estimates',
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _spendCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final store = context.read<HabitStore>();
    final spend = double.tryParse(_spendCtrl.text.trim()) ?? store.dailySpend;
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? store.dailyHours;

    store.setPreferredCurrency(_currencyChoice);
    store.setPersonalPlan(
      goalType: _goalType,
      quitReason: _reasonCtrl.text,
      triggerProfile: _triggerProfile.toList(),
      milestoneDays: _milestoneDays,
    );
    store.setDailyEstimates(spendPerDay: spend, hoursPerDay: hours);

    try {
      await HabitApi().postPreferences(
        store,
        dailySpend: store.dailySpend,
        dailyHours: store.dailyHours,
        onboardingCompleted: true,
        goalType: store.goalType,
        quitReason: store.quitReason,
        triggerProfile: store.triggerProfile,
        milestoneDays: store.milestoneDays,
        preferredCurrency: store.preferredCurrency,
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const HaptiveAppShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final currencySymbol = CurrencyFormat.symbol(
      context,
      preferredCurrency: _currencyChoice,
    );

    return Scaffold(
      key: const ValueKey('onboarding-screen'),
      backgroundColor: HaptiveColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _stepCount,
                        minHeight: 3,
                        backgroundColor: const Color(0xFF1C1C1E),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          HaptiveColors.clean,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${_step + 1}/$_stepCount',
                    style: text.labelSmall?.copyWith(
                      color: HaptiveColors.label,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_step),
                    child: _stepPage(
                      text: text,
                      currencySymbol: currencySymbol,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      style: TextButton.styleFrom(
                        foregroundColor: HaptiveColors.label,
                        minimumSize: const Size(72, _kOnboardingButtonHeight),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _step < _stepCount - 1
                        ? () => setState(() => _step++)
                        : _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, _kOnboardingButtonHeight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_step < _stepCount - 1 ? 'Continue' : 'Enter app'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepPage({
    required TextTheme text,
    required String currencySymbol,
  }) {
    final headline = _headlines[_step];
    switch (_step) {
      case 0:
        return _StepGoal(
          headline: headline,
          text: text,
          goalType: _goalType,
          onGoalChanged: (v) => setState(() => _goalType = v),
        );
      case 1:
        return _StepReason(
          headline: headline,
          text: text,
          reasonCtrl: _reasonCtrl,
          triggerOptions: _triggerOptions,
          triggerProfile: _triggerProfile,
          onTriggerToggle: (label, on) {
            setState(() {
              if (on) {
                _triggerProfile.add(label);
              } else {
                _triggerProfile.remove(label);
              }
            });
          },
        );
      case 2:
        return _StepMilestone(
          headline: headline,
          text: text,
          milestoneDays: _milestoneDays,
          onPick: (d) => setState(() => _milestoneDays = d),
        );
      case 3:
        return _StepCurrency(
          headline: headline,
          text: text,
          currencyChoice: _currencyChoice,
          onPick: (c) => setState(() => _currencyChoice = c),
        );
      default:
        return _StepEstimates(
          headline: headline,
          text: text,
          spendCtrl: _spendCtrl,
          hoursCtrl: _hoursCtrl,
          currencySymbol: currencySymbol,
        );
    }
  }
}

/// Full-width connected control — labels scale down if needed so nothing clips
/// (SegmentedButton can truncate on narrow / web layouts).
class _OnboardingSegmentBar extends StatelessWidget {
  const _OnboardingSegmentBar({
    required this.text,
    required this.entries,
    required this.selected,
    required this.onChanged,
  });

  final TextTheme text;
  final List<({String value, String label})> entries;
  final String selected;
  final ValueChanged<String> onChanged;

  static const _border = Color(0xFF2C2C2E);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kOnboardingButtonHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          color: HaptiveColors.surface,
        ),
        padding: const EdgeInsets.all(1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: _border,
                ),
              Expanded(
                child: _SegmentCell(
                  text: text,
                  label: entries[i].label,
                  selected: selected == entries[i].value,
                  isFirst: i == 0,
                  isLast: i == entries.length - 1,
                  onTap: () => onChanged(entries[i].value),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  const _SegmentCell({
    required this.text,
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final TextTheme text;
  final String label;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(12) : Radius.zero,
      right: isLast ? const Radius.circular(12) : Radius.zero,
    );

    return Material(
      color: selected
          ? HaptiveColors.clean.withValues(alpha: 0.18)
          : HaptiveColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: selected ? HaptiveColors.clean : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.text, required this.title});

  final TextTheme text;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: text.headlineSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.2,
      ),
    );
  }
}

class _StepGoal extends StatelessWidget {
  const _StepGoal({
    required this.headline,
    required this.text,
    required this.goalType,
    required this.onGoalChanged,
  });

  final String headline;
  final TextTheme text;
  final String goalType;
  final ValueChanged<String> onGoalChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('onboarding-step-goal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headline(text: text, title: headline),
        const SizedBox(height: 36),
        _OnboardingSegmentBar(
          text: text,
          entries: const [
            (value: 'quit', label: 'Quit'),
            (value: 'reduce', label: 'Reduce'),
          ],
          selected: goalType,
          onChanged: onGoalChanged,
        ),
        const Spacer(),
        Text(
          'You can change this later in Profile.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: HaptiveColors.label),
        ),
      ],
    );
  }
}

class _StepReason extends StatelessWidget {
  const _StepReason({
    required this.headline,
    required this.text,
    required this.reasonCtrl,
    required this.triggerOptions,
    required this.triggerProfile,
    required this.onTriggerToggle,
  });

  final String headline;
  final TextTheme text;
  final TextEditingController reasonCtrl;
  final List<String> triggerOptions;
  final Set<String> triggerProfile;
  final void Function(String label, bool on) onTriggerToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('onboarding-step-reason'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headline(text: text, title: headline),
        const SizedBox(height: 20),
        TextField(
          controller: reasonCtrl,
          maxLines: 4,
          style: text.bodyLarge?.copyWith(
            color: Colors.white,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: 'A sentence is enough.',
            hintStyle: text.bodyLarge?.copyWith(color: HaptiveColors.label),
            filled: true,
            fillColor: HaptiveColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: HaptiveColors.clean),
            ),
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Triggers (optional)',
          style: text.labelSmall?.copyWith(color: HaptiveColors.label),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: triggerOptions.map((label) {
            final on = triggerProfile.contains(label);
            final borderColor = on ? HaptiveColors.clean : HaptiveColors.label;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTriggerToggle(label, !on),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Text(
                    label,
                    style: text.bodyMedium?.copyWith(
                      fontSize: 16,
                      color: on ? HaptiveColors.clean : HaptiveColors.label,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StepMilestone extends StatelessWidget {
  const _StepMilestone({
    required this.headline,
    required this.text,
    required this.milestoneDays,
    required this.onPick,
  });

  final String headline;
  final TextTheme text;
  final int milestoneDays;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('onboarding-step-milestone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headline(text: text, title: headline),
        const SizedBox(height: 28),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: HabitStore.milestoneOptions.map((days) {
            final selected = milestoneDays == days;
            return InkWell(
              onTap: () => onPick(days),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? HaptiveColors.clean : const Color(0xFF2C2C2E),
                    width: selected ? 1.5 : 1,
                  ),
                  color: selected
                      ? const Color(0x14D4FF00)
                      : HaptiveColors.surface,
                ),
                child: Text(
                  '$days days',
                  style: text.bodyMedium?.copyWith(
                    color: selected ? HaptiveColors.clean : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const Spacer(),
      ],
    );
  }
}

class _StepCurrency extends StatelessWidget {
  const _StepCurrency({
    required this.headline,
    required this.text,
    required this.currencyChoice,
    required this.onPick,
  });

  final String headline;
  final TextTheme text;
  final String currencyChoice;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('onboarding-step-currency'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headline(text: text, title: headline),
        const SizedBox(height: 8),
        Text(
          'For money saved and daily spend.',
          style: text.bodyMedium?.copyWith(color: HaptiveColors.label),
        ),
        const SizedBox(height: 28),
        _OnboardingSegmentBar(
          text: text,
          entries: const [
            (value: 'auto', label: 'Auto'),
            (value: 'INR', label: '₹ INR'),
            (value: 'USD', label: r'$ USD'),
          ],
          selected: currencyChoice,
          onChanged: onPick,
        ),
        const Spacer(),
      ],
    );
  }
}

class _StepEstimates extends StatelessWidget {
  const _StepEstimates({
    required this.headline,
    required this.text,
    required this.spendCtrl,
    required this.hoursCtrl,
    required this.currencySymbol,
  });

  final String headline;
  final TextTheme text;
  final TextEditingController spendCtrl;
  final TextEditingController hoursCtrl;
  final String currencySymbol;

  InputDecoration _fieldDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: text.bodySmall?.copyWith(color: HaptiveColors.label),
      hintStyle: text.bodyMedium?.copyWith(color: HaptiveColors.label),
      filled: true,
      fillColor: HaptiveColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HaptiveColors.clean),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('onboarding-step-estimates'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headline(text: text, title: headline),
        const SizedBox(height: 24),
        TextField(
          controller: spendCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: text.bodyLarge?.copyWith(color: Colors.white),
          decoration: _fieldDeco(
            'Daily spend ($currencySymbol)',
            hint: '12.5',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: hoursCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: text.bodyLarge?.copyWith(color: Colors.white),
          decoration: _fieldDeco('Hours per day', hint: '1.5'),
        ),
      ],
    );
  }
}
