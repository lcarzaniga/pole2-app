import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format.dart';
import '../../places/application/place_providers.dart';
import '../../places/presentation/place_picker.dart';
import '../application/event_providers.dart';
import '../application/transfer_validation.dart';

/// "Torna tra i miei oggetti": a given possession comes back to the user. Pick
/// the date it returned (not before it was given, not in the future) and where
/// it goes — the original place preselected when it's still reachable, or any
/// place / none via the hierarchical picker. Commits transactionally, keeping
/// the original transfer event so the full history stays true.
Future<void> showReacquireSheet(
  BuildContext context, {
  required String possessionId,
  required PossessionEvent transfer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ReacquireSheet(possessionId: possessionId, transfer: transfer),
  );
}

class _ReacquireSheet extends ConsumerStatefulWidget {
  const _ReacquireSheet({required this.possessionId, required this.transfer});

  final String possessionId;
  final PossessionEvent transfer;

  @override
  ConsumerState<_ReacquireSheet> createState() => _ReacquireSheetState();
}

class _ReacquireSheetState extends ConsumerState<_ReacquireSheet> {
  late DateTime _date;
  String? _placeId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _placeId = widget.transfer.originPlaceId; // validated on save
  }

  bool get _dateValid => reacquireDateValid(_date, widget.transfer.at);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.transfer.at, // can't predate the transfer
      lastDate: now, // nor be in the future
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPlace() async {
    final choice = await showPlacePicker(context, currentPlaceId: _placeId);
    if (choice == null) return;
    setState(() => _placeId = choice.placeId);
  }

  Future<void> _confirm() async {
    if (_saving || !_dateValid) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref
        .read(eventsDaoProvider)
        .reacquire(
          possessionId: widget.possessionId,
          reacquiredAt: _date,
          placeId: _placeId,
        );
    navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.reacquiredSnack),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
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
              Text(l10n.reacquireTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.reacquireDateLabel,
                  errorText: _dateValid
                      ? null
                      : l10n.reacquireBeforeTransferError,
                ),
                child: InkWell(
                  onTap: _pickDate,
                  child: Text(
                    formatDate(_date, l10n.localeName),
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
                onPressed: _saving || !_dateValid ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.reacquireAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
