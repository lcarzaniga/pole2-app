import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../../shared/format.dart';
import '../application/event_providers.dart';
import '../application/possession_providers.dart';
import '../application/transfer_validation.dart';
import 'person_picker.dart';
import 'widgets/entity_context_title.dart';

/// Record giving a possession away for good. A calm, deliberate form — recipient,
/// the date it was given (never the future), an optional note — whose copy makes
/// the effect clear (leaves Home/Place, stays safe in Archivio). The editor is
/// the confirmation; there's no extra alarming dialog. Pops `true` on success so
/// callers (detail, review) can react; shows its own Undo snackbar.
class GiveEditorScreen extends ConsumerStatefulWidget {
  const GiveEditorScreen({super.key, required this.possessionId});

  final String possessionId;

  @override
  ConsumerState<GiveEditorScreen> createState() => _GiveEditorScreenState();
}

class _GiveEditorScreenState extends ConsumerState<GiveEditorScreen> {
  final _note = TextEditingController();
  String? _recipientName;
  String? _recipientPartyId;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      canSaveTransfer(
        recipientName: _recipientName ?? '',
        transferredAt: _date,
      );

  Future<void> _pickRecipient() async {
    final choice = await showPersonPicker(context);
    if (choice == null) return;
    setState(() {
      _recipientName = choice.name;
      _recipientPartyId = choice.partyId;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now, // no future transfer
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(eventsDaoProvider);
    try {
      final event = await dao.give(
        possessionId: widget.possessionId,
        personName: _recipientName!,
        partyId: _recipientPartyId,
        transferredAt: _date,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (event == null) {
        // Blocked (e.g. a race with a loan) — leave everything untouched.
        if (mounted) setState(() => _saving = false);
        return;
      }
      HapticFeedback.lightImpact();
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.givenSavedSnack),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => dao.undoGive(
                possessionId: widget.possessionId,
                transferEventId: event.id,
              ),
            ),
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
    final dateValid = transferDateValid(_date);

    return Scaffold(
      appBar: AppBar(
        title: EntityContextTitle(
          objectName: possession.value?.title,
          action: l10n.giveEditTitle,
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(l10n.saveButton),
          ),
        ],
      ),
      body: ListView(
        padding: padWithSafeBottom(
          context,
          const EdgeInsets.all(AppSpacing.lg),
        ),
        children: [
          InkWell(
            onTap: _pickRecipient,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.giveRecipientLabel,
                prefixIcon: const Icon(Icons.card_giftcard_outlined),
              ),
              child: Text(
                _recipientName ?? l10n.giveRecipientChoose,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _recipientName == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.giveDateLabel,
              errorText: dateValid ? null : l10n.transferDateFutureError,
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
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.giveNoteLabel),
          ),
          const SizedBox(height: AppSpacing.xl),
          // The deliberate confirmation copy: what giving actually does.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: AppSpacing.lg,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.giveEffectHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
