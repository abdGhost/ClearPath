import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/haptive_theme.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.syncing,
    required this.label,
  });

  final bool syncing;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final effective = (label == null || label!.trim().isEmpty)
        ? (syncing ? 'Syncing...' : 'Local')
        : label!;
    final accent = syncing ? HaptiveColors.progress : HaptiveColors.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            syncing ? LucideIcons.refreshCw : LucideIcons.cloud,
            size: 11,
            color: accent,
          ),
          const SizedBox(width: 5),
          Text(
            effective,
            style: text.labelSmall?.copyWith(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

