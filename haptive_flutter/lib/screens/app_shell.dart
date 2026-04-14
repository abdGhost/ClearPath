import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/habit_api.dart';
import '../state/habit_store.dart';
import '../theme/haptive_theme.dart';
import '../utils/currency_format.dart';
import 'analytics_screen.dart';
import 'pulse_dashboard.dart';

const Color _kPlanFieldBorder = Color(0xFF2C2C2E);

InputDecoration _personalPlanFieldDecoration(
  TextTheme text, {
  required String labelText,
  String? hintText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    labelStyle: text.bodySmall?.copyWith(color: HaptiveColors.label),
    hintStyle: text.bodyMedium?.copyWith(
      color: HaptiveColors.label.withValues(alpha: 0.75),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    filled: true,
    fillColor: HaptiveColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kPlanFieldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kPlanFieldBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: HaptiveColors.clean, width: 1.5),
    ),
  );
}

/// Main app shell with bottom [NavigationBar] (Haptive-styled).
class HaptiveAppShell extends StatefulWidget {
  const HaptiveAppShell({super.key});

  @override
  State<HaptiveAppShell> createState() => _HaptiveAppShellState();
}

class _HaptiveAppShellState extends State<HaptiveAppShell> {
  final _api = HabitApi();
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<HabitStore>();
      try {
        await _api.applyRemoteState(store);
      } catch (_) {
        /* offline — local store only */
      }
    });
  }

  void _onNav(int index) {
    HapticFeedback.selectionClick();
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaptiveColors.background,
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          PulseDashboard(),
          AnalyticsScreen(embedded: true),
          _MoreTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: HaptiveColors.surface,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 74,
            backgroundColor: HaptiveColors.surface,
            surfaceTintColor: Colors.transparent,
            selectedIndex: _tabIndex,
            onDestinationSelected: _onNav,
            destinations: [
              NavigationDestination(
                icon: const Icon(LucideIcons.activity),
                selectedIcon: const Icon(
                  LucideIcons.activity,
                  color: HaptiveColors.clean,
                ),
                label: 'Pulse',
              ),
              NavigationDestination(
                icon: const Icon(LucideIcons.barChart2),
                selectedIcon: const Icon(
                  LucideIcons.barChart2,
                  color: HaptiveColors.progress,
                ),
                label: 'Analytics',
              ),
              NavigationDestination(
                icon: const Icon(LucideIcons.user),
                selectedIcon: const Icon(
                  LucideIcons.user,
                  color: HaptiveColors.clean,
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab();

  Future<void> _syncStore(BuildContext context) async {
    try {
      await HabitApi().applyRemoteState(context.read<HabitStore>());
    } catch (_) {}
  }

  Future<void> _confirmRelapse(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: HaptiveColors.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Reset streak?',
            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          content: Text(
            'The timer restarts from now. Your history stays in Analytics.',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: HaptiveColors.label,
                  height: 1.4,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: HaptiveColors.label),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Reset',
                style: TextStyle(
                  color: HaptiveColors.clean,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;
    HapticFeedback.heavyImpact();
    final store = context.read<HabitStore>();
    final now = DateTime.now().toUtc();
    try {
      await HabitApi().postRelapse(store, at: now);
    } catch (_) {
      store.setLastRelapse(now);
    }
  }

  Future<void> _editEstimates(BuildContext context, HabitStore store) async {
    var goalType = store.goalType;
    var milestoneDays = store.milestoneDays;
    var preferredCurrency = store.preferredCurrency;
    final reasonCtrl = TextEditingController(text: store.quitReason);
    final spendCtrl =
        TextEditingController(text: store.dailySpend.toStringAsFixed(2));
    final hoursCtrl =
        TextEditingController(text: store.dailyHours.toStringAsFixed(1));
    final triggerProfile = {...store.triggerProfile};
    const triggerOptions = [
      'Stress',
      'Boredom',
      'Social',
      'Lonely',
      'Late night',
      'After meals',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        final currencySymbol = CurrencyFormat.symbol(
          ctx,
          preferredCurrency: preferredCurrency,
        );
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: HaptiveColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Personal plan',
              style: text.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: goalType,
                      dropdownColor: HaptiveColors.surface,
                      style: text.bodyMedium?.copyWith(color: Colors.white),
                      iconEnabledColor: HaptiveColors.label,
                      items: const [
                        DropdownMenuItem(value: 'quit', child: Text('Quit')),
                        DropdownMenuItem(value: 'reduce', child: Text('Reduce')),
                      ],
                      onChanged: (v) => setDialogState(() => goalType = v ?? 'quit'),
                      decoration: _personalPlanFieldDecoration(text, labelText: 'Goal'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      style: text.bodyMedium?.copyWith(color: Colors.white),
                      decoration: _personalPlanFieldDecoration(
                        text,
                        labelText: 'Reason',
                        hintText: 'Why this matters to you',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: milestoneDays,
                      dropdownColor: HaptiveColors.surface,
                      style: text.bodyMedium?.copyWith(color: Colors.white),
                      iconEnabledColor: HaptiveColors.label,
                      items: HabitStore.milestoneOptions
                          .map((e) => DropdownMenuItem(value: e, child: Text('$e days')))
                          .toList(),
                      onChanged: (v) => setDialogState(() => milestoneDays = v ?? 30),
                      decoration: _personalPlanFieldDecoration(text, labelText: 'Milestone'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: preferredCurrency,
                      dropdownColor: HaptiveColors.surface,
                      style: text.bodyMedium?.copyWith(color: Colors.white),
                      iconEnabledColor: HaptiveColors.label,
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('Auto (device region)')),
                        DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                        DropdownMenuItem(value: 'USD', child: Text(r'USD ($)')),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => preferredCurrency = v ?? 'auto'),
                      decoration: _personalPlanFieldDecoration(text, labelText: 'Currency'),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Trigger profile',
                      style: text.labelSmall?.copyWith(color: HaptiveColors.label),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: triggerOptions.map((label) {
                        final selected = triggerProfile.contains(label);
                        final borderColor =
                            selected ? HaptiveColors.clean : HaptiveColors.label;
                        return FilterChip(
                          label: Text(label),
                          selected: selected,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          selectedColor: HaptiveColors.clean.withValues(alpha: 0.16),
                          side: BorderSide(color: borderColor, width: 1),
                          labelStyle: text.bodySmall?.copyWith(
                            color: selected ? HaptiveColors.clean : HaptiveColors.label,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          onSelected: (on) {
                            setDialogState(() {
                              if (on) {
                                triggerProfile.add(label);
                              } else {
                                triggerProfile.remove(label);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: spendCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: text.bodyMedium?.copyWith(color: Colors.white),
                      decoration: _personalPlanFieldDecoration(
                        text,
                        labelText: 'Daily spend ($currencySymbol)',
                        hintText: 'e.g. 12.5',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: hoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: text.bodyMedium?.copyWith(color: Colors.white),
                      decoration: _personalPlanFieldDecoration(
                        text,
                        labelText: 'Daily time (hours)',
                        hintText: 'e.g. 1.5',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: HaptiveColors.label),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    final reasonText = reasonCtrl.text;
    final spendText = spendCtrl.text.trim();
    final hoursText = hoursCtrl.text.trim();

    if (ok != true || !context.mounted) return;
    final spend = double.tryParse(spendText);
    final hours = double.tryParse(hoursText);
    if (spend == null || hours == null || spend < 0 || hours < 0) return;

    store.setPersonalPlan(
      goalType: goalType,
      quitReason: reasonText,
      triggerProfile: triggerProfile.toList(),
      milestoneDays: milestoneDays,
    );
    store.setDailyEstimates(spendPerDay: spend, hoursPerDay: hours);
    store.setPreferredCurrency(preferredCurrency);
    try {
      await HabitApi().postPreferences(
        store,
        dailySpend: spend,
        dailyHours: hours,
        onboardingCompleted: true,
        goalType: goalType,
        quitReason: reasonText,
        triggerProfile: triggerProfile.toList(),
        milestoneDays: milestoneDays,
        preferredCurrency: preferredCurrency,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = context.watch<HabitStore>();

    return Scaffold(
      backgroundColor: HaptiveColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: HaptiveColors.clean,
          backgroundColor: HaptiveColors.surface,
          onRefresh: () => _syncStore(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
            children: [
              Text(
                'Profile',
                style: text.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your streak · tools',
                style: text.labelSmall?.copyWith(
                  color: HaptiveColors.label.withValues(alpha: 0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _ProfileStatChip(
                        label: 'Streak',
                        value: '${store.cleanDays}d',
                        icon: LucideIcons.target,
                        accent: HaptiveColors.clean,
                      ),
                    ),
                    _profileStatDivider(),
                    Expanded(
                      child: _ProfileStatChip(
                        label: 'Resists',
                        value: '${store.resistCount}',
                        icon: LucideIcons.shield,
                        accent: HaptiveColors.progress,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ProfileSection(
                onTap: () => _editEstimates(context, store),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileSectionTitle(
                      text: text,
                      icon: LucideIcons.wallet,
                      iconColor: HaptiveColors.clean,
                      title: 'Personal plan',
                      subtitle: 'Goal, milestone, triggers, and personal estimates.',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          '${store.milestoneDays}d · ${CurrencyFormat.amount(context, store.dailySpend, preferredCurrency: store.preferredCurrency)}/day',
                          style: text.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: HaptiveColors.label,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ProfileSection(
                onTap: () => _confirmRelapse(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileSectionTitle(
                      text: text,
                      icon: LucideIcons.rotateCcw,
                      iconColor: HaptiveColors.clean,
                      title: 'Start date',
                      subtitle: 'Restart your counter after a slip. History stays in Analytics.',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Reset streak',
                          style: text.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: HaptiveColors.label,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ProfileSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileSectionTitle(
                      text: text,
                      icon: LucideIcons.sparkles,
                      iconColor: HaptiveColors.clean,
                      title: 'Haptive',
                      subtitle: 'Habit support built for tough moments.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'More settings and sync options coming soon.',
                      style: text.bodySmall?.copyWith(
                        color: HaptiveColors.label,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _profileStatDivider() {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            HaptiveColors.border.withValues(alpha: 0.65),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Matches Analytics `_AnalyticsSurface` — one cohesive module style.
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF141418),
            HaptiveColors.surface.withValues(alpha: 0.92),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: box,
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({
    required this.text,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final TextTheme text;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: iconColor.withValues(alpha: 0.12),
            border: Border.all(color: iconColor.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: text.labelSmall?.copyWith(
                  color: HaptiveColors.label.withValues(alpha: 0.92),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileStatChip extends StatelessWidget {
  const _ProfileStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, size: 22, color: accent),
        const SizedBox(height: 6),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: text.labelSmall?.copyWith(
            fontSize: 11,
            color: HaptiveColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
