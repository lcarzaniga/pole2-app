import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format.dart';
import '../../places/application/place_providers.dart';
import '../../places/presentation/place_picker.dart';
import '../application/event_providers.dart';

/// A lightweight return sheet: confirm the actual return date and where the
/// thing goes back. The previous place is preselected when it still exists;
/// otherwise it falls back to "no place". Tapping "Segna come restituito" is the
/// deliberate confirmation — the return commits transactionally (no risky Undo;
/// a mistaken borrower/place is easily re-lent or reassigned afterwards).
Future<void> showReturnSheet(
  BuildContext context, {
  required String possessionId,
  required PossessionEvent loan,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReturnSheet(possessionId: possessionId, loan: loan),
  );
}

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet({required this.possessionId, required this.loan});

  final String possessionId;
  final PossessionEvent loan;

  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  late DateTime _returnedAt;
  String? _placeId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _returnedAt = DateTime.now();
    _placeId = widget.loan.originPlaceId; // validated on save
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 100),
    );
    if (picked != null) setState(() => _returnedAt = picked);
  }

  Future<void> _pickPlace() async {
    final choice = await showPlacePicker(context, currentPlaceId: _placeId);
    if (choice == null) return;
    setState(() => _placeId = choice.placeId);
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    await ref
        .read(eventsDaoProvider)
        .returnLoan(
          possessionId: widget.possessionId,
          loanEventId: widget.loan.id,
          returnedAt: _returnedAt,
          returnPlaceId: _placeId,
        );
    navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.loanReturned),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    // A deleted place resolves to null → shown (and returned) as "no place".
    final place = _placeId == null
        ? null
        : ref.watch(placeByIdProvider(_placeId!)).value;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.returnTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              InputDecorator(
                decoration: InputDecoration(labelText: l10n.returnActualDate),
                child: InkWell(
                  onTap: _pickDate,
                  child: Text(
                    formatDate(_returnedAt, l10n.localeName),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              InputDecorator(
                decoration: InputDecoration(labelText: l10n.returnPlaceLabel),
                child: InkWell(
                  onTap: _pickPlace,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          place?.name ?? l10n.noPlace,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: place == null
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.markReturned),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
