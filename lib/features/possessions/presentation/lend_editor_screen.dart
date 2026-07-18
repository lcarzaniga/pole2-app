import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format.dart';
import '../../../shared/phrasing.dart';
import '../application/event_providers.dart';
import '../application/loan_validation.dart';
import '../application/possession_providers.dart';
import 'person_picker.dart';
import 'widgets/entity_context_title.dart';

/// Values passed when opening the editor to *correct* an existing loan. Absent
/// (null) means a fresh lend.
class LendEditData {
  const LendEditData({
    required this.loanEventId,
    required this.borrowerName,
    required this.borrowerPartyId,
    required this.lentAt,
    required this.expectedReturn,
    required this.lead,
  });

  final String loanEventId;
  final String borrowerName;
  final String? borrowerPartyId;
  final DateTime lentAt;
  final DateTime? expectedReturn;
  final ReminderLead? lead;
}

/// Lend a possession to a person, or correct an active loan. A calm form:
/// borrower, lent date (today by default), an optional expected return, and —
/// only when a return date is set — an optional reminder. Pops `true` on a
/// successful save so callers (e.g. the review flow) can react.
class LendEditorScreen extends ConsumerStatefulWidget {
  const LendEditorScreen({super.key, required this.possessionId, this.edit});

  final String possessionId;
  final LendEditData? edit;

  @override
  ConsumerState<LendEditorScreen> createState() => _LendEditorScreenState();
}

class _LendEditorScreenState extends ConsumerState<LendEditorScreen> {
  String? _borrowerName;
  String? _borrowerPartyId;
  late DateTime _lentAt;
  DateTime? _expectedReturn;
  ReminderLead? _lead;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _lentAt = e?.lentAt ?? DateTime.now();
    _borrowerName = e?.borrowerName;
    _borrowerPartyId = e?.borrowerPartyId;
    _expectedReturn = e?.expectedReturn;
    _lead = e?.lead;
  }

  bool get _canSave =>
      !_saving &&
      canSaveLoan(
        borrowerName: _borrowerName ?? '',
        lentAt: _lentAt,
        expectedReturn: _expectedReturn,
      );

  Future<void> _pickBorrower() async {
    final choice = await showPersonPicker(context);
    if (choice == null) return;
    setState(() {
      _borrowerName = choice.name;
      _borrowerPartyId = choice.partyId;
    });
  }

  Future<void> _pickLentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lentAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 100),
    );
    if (picked == null) return;
    setState(() {
      _lentAt = picked;
      // Keep the return date consistent: never before the lent date.
      if (_expectedReturn != null &&
          dateOnly(_expectedReturn!).isBefore(dateOnly(picked))) {
        _expectedReturn = picked;
      }
    });
  }

  Future<void> _pickReturnDate() async {
    final base = _expectedReturn ?? _lentAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: base.isBefore(_lentAt) ? _lentAt : base,
      firstDate: _lentAt,
      lastDate: DateTime(DateTime.now().year + 100),
    );
    if (picked != null) setState(() => _expectedReturn = picked);
  }

  void _clearReturnDate() {
    setState(() {
      _expectedReturn = null;
      _lead = null; // no return date → no return reminder
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final dao = ref.read(eventsDaoProvider);
    try {
      if (_isEdit) {
        await dao.updateLoan(
          widget.edit!.loanEventId,
          personName: _borrowerName!,
          partyId: _borrowerPartyId,
          expectedReturn: _expectedReturn,
          lead: _lead,
        );
      } else {
        await dao.lend(
          possessionId: widget.possessionId,
          personName: _borrowerName!,
          partyId: _borrowerPartyId,
          lentAt: _lentAt,
          expectedReturn: _expectedReturn,
          lead: _lead,
        );
      }
      HapticFeedback.lightImpact();
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(_isEdit ? l10n.loanUpdated : l10n.loanStarted),
          ),
        );
      context.pop(true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final possession = ref.watch(possessionByIdProvider(widget.possessionId));
    final datesValid = loanDatesValid(_lentAt, _expectedReturn);

    return Scaffold(
      appBar: AppBar(
        title: EntityContextTitle(
          objectName: possession.value?.title,
          action: _isEdit ? l10n.lendEditTitle : l10n.lendToSomeone,
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(l10n.saveButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Borrower
          InkWell(
            onTap: _pickBorrower,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.borrowerLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              child: Text(
                _borrowerName ?? l10n.borrowerChoose,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _borrowerName == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Lent date
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.lentDateLabel),
            child: InkWell(
              onTap: _pickLentDate,
              child: Text(
                formatDate(_lentAt, l10n.localeName),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Expected return (optional)
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.expectedReturnOptional,
              errorText: datesValid ? null : l10n.loanDatesInvalid,
              suffixIcon: _expectedReturn == null
                  ? null
                  : IconButton(
                      tooltip: l10n.returnDateClear,
                      icon: const Icon(Icons.clear),
                      onPressed: _clearReturnDate,
                    ),
            ),
            child: InkWell(
              onTap: _pickReturnDate,
              child: Text(
                _expectedReturn == null
                    ? l10n.noReturnDate
                    : formatDate(_expectedReturn!, l10n.localeName),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _expectedReturn == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
          // Reminder — only meaningful once a return date exists.
          if (_expectedReturn != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.returnReminder, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final lead in ReminderLead.values)
                  ChoiceChip(
                    label: Text(reminderLeadLabel(l10n, lead)),
                    selected: _lead == lead,
                    onSelected: (sel) =>
                        setState(() => _lead = sel ? lead : null),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
