import 'package:flutter/material.dart';

import '../../../../app/theme/app_icon_size.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/format.dart';

/// The calm custody card shown on a possession's detail while it is lent out:
/// who has it, since when, when it's due back, and a way to correct the loan or
/// mark it returned. Purely presentational — data and actions are injected — so
/// it renders without any Drift stream. The state never relies on colour alone
/// (an explicit icon + "Prestato a …" text carry the meaning).
class CustodyCard extends StatelessWidget {
  const CustodyCard({
    super.key,
    required this.borrowerName,
    required this.lentAt,
    required this.expectedReturn,
    required this.hasReminder,
    required this.onEdit,
    required this.onReturn,
  });

  final String borrowerName;
  final DateTime lentAt;
  final DateTime? expectedReturn;
  final bool hasReminder;
  final VoidCallback onEdit;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final lines = <String>[
      l10n.lentOn(formatDate(lentAt, l10n.localeName)),
      if (expectedReturn != null)
        l10n.expectedReturnOn(formatDate(expectedReturn!, l10n.localeName)),
      if (expectedReturn != null && hasReminder) l10n.returnReminderSet,
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.people_alt_outlined,
                size: AppIconSize.md,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lentToPerson(borrowerName),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final line in lines)
                      Text(
                        line,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.lendEditTitle,
                icon: const Icon(Icons.edit_outlined),
                iconSize: AppIconSize.md,
                color: scheme.onSurfaceVariant,
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onReturn,
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: Text(l10n.markReturned),
            ),
          ),
        ],
      ),
    );
  }
}
