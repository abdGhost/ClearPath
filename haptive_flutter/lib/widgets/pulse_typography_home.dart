import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../state/habit_store.dart';
import '../theme/haptive_theme.dart';
import '../utils/currency_format.dart';

/// Minimal, typography-led home (ring hero + inline stats — common in 2024 habit UIs).
class PulseTypographyHome extends StatelessWidget {
  const PulseTypographyHome({super.key, required this.store});

  final HabitStore store;

  static const _refDays = 30;

  static int _weekFilledSlots(HabitStore s) {
    if (s.cleanDays <= 0) return 0;
    return ((s.cleanDays - 1) % 7) + 1;
  }

  static String _fmtTime(HabitStore s) {
    final h = s.timeReclaimedHours;
    if (h >= 1) return '${h.toStringAsFixed(1)} h';
    return '${(h * 60).round()} min';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final milestoneDays = store.milestoneDays;
    final weekN = _weekFilledSlots(store);
    final pastMilestone = store.cleanDays >= milestoneDays;
    final ringValue = pastMilestone
        ? 1.0
        : (store.cleanDays / milestoneDays).clamp(0.0, 1.0);
    final daysLeft =
        (pastMilestone ? 0 : (milestoneDays - store.cleanDays)).clamp(0, milestoneDays);
    final moneyDenom = (_refDays * store.dailySpend).clamp(0.0001, double.infinity);
    final timeDenom = (_refDays * store.dailyHours).clamp(0.0001, double.infinity);
    final moneyP = (store.moneySaved / moneyDenom).clamp(0.0, 1.0);
    final timeP = (store.timeReclaimedHours / timeDenom).clamp(0.0, 1.0);

    return Column(
      key: const ValueKey('pulse-typography-home'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -math.pi / 2,
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: ringValue,
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFF161618),
                      color: HaptiveColors.clean,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${store.cleanDays}',
                      style: text.displayLarge?.copyWith(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: HaptiveColors.clean,
                        height: 1,
                        letterSpacing: -3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'days clean',
                      style: text.labelSmall?.copyWith(
                        color: HaptiveColors.label,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${store.cleanHoursRemainder} h  ·  ${store.resistCount} resists',
                      style: text.labelSmall?.copyWith(
                        color: HaptiveColors.label.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _StatColumn(
                label: 'Saved',
                value: CurrencyFormat.amount(
                  context,
                  store.moneySaved,
                  preferredCurrency: store.preferredCurrency,
                ),
                accent: HaptiveColors.clean,
                progress: moneyP,
              ),
            ),
            Container(
              width: 1,
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: HaptiveColors.border.withValues(alpha: 0.5),
            ),
            Expanded(
              child: _StatColumn(
                label: 'Time back',
                value: _fmtTime(store),
                accent: HaptiveColors.progress,
                progress: timeP,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Estimate: ${CurrencyFormat.amount(context, store.dailySpend, preferredCurrency: store.preferredCurrency)}/day and '
          '${store.dailyHours.toStringAsFixed(1)} h/day from your profile settings.',
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(
            color: HaptiveColors.label.withValues(alpha: 0.8),
            fontSize: 11,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (i) {
            final on = i < weekN;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: on ? 9 : 7,
                height: on ? 9 : 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on
                      ? HaptiveColors.clean
                      : HaptiveColors.border.withValues(alpha: 0.45),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color:
                                HaptiveColors.clean.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Path to $milestoneDays days',
                  style: text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              Text(
                pastMilestone ? '$milestoneDays+' : '${store.cleanDays} / $milestoneDays',
                style: text.labelSmall?.copyWith(
                  color: pastMilestone
                      ? HaptiveColors.clean
                      : HaptiveColors.label.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ringValue,
            minHeight: 5,
            backgroundColor: HaptiveColors.border.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation<Color>(
              pastMilestone ? HaptiveColors.clean : HaptiveColors.progress,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pastMilestone
              ? 'First milestone reached — keep the streak.'
              : daysLeft == 1
                  ? '1 day until your first milestone.'
                  : '$daysLeft days until your first milestone.',
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(
            color: HaptiveColors.label.withValues(alpha: 0.82),
            fontSize: 11,
            letterSpacing: 0.25,
            height: 1.35,
          ),
        ),
        if (store.lastResistSummary != null ||
            store.lastMoodSummary != null) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (store.lastResistSummary != null)
                  _PulseActivityRow(
                    icon: LucideIcons.shield,
                    label: store.lastResistSummary!,
                    accent: HaptiveColors.progress,
                  ),
                if (store.lastMoodSummary != null) ...[
                  if (store.lastResistSummary != null)
                    const SizedBox(height: 10),
                  _PulseActivityRow(
                    icon: LucideIcons.tag,
                    label: store.lastMoodSummary!,
                    accent: HaptiveColors.clean.withValues(alpha: 0.95),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PulseActivityRow extends StatelessWidget {
  const _PulseActivityRow({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: text.labelMedium?.copyWith(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.accent,
    required this.progress,
  });

  final String label;
  final String value;
  final Color accent;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(
            color: HaptiveColors.label,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: HaptiveColors.border.withValues(alpha: 0.28),
            valueColor: AlwaysStoppedAnimation<Color>(
              accent.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}
