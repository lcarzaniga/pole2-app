import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../../shared/format.dart';
import '../../../shared/phrasing.dart';
import '../application/event_providers.dart';
import '../application/possession_providers.dart';
import 'widgets/entity_context_title.dart';

/// Create one simple deadline connected to a thing. Title and a date are all
/// that's needed; the note and advance notice are optional.
class ReminderEditorScreen extends ConsumerStatefulWidget {
  const ReminderEditorScreen({super.key, required this.possessionId});

  final String possessionId;

  @override
  ConsumerState<ReminderEditorScreen> createState() =>
      _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  DateTime? _date;
  ReminderLead? _lead;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty && _date != null;

  Future<void> _save() async {
    if (!_canSave) return;
    await ref
        .read(eventsDaoProvider)
        .createReminder(
          possessionId: widget.possessionId,
          title: _title.text.trim(),
          at: _date!,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          lead: _lead,
        );
    HapticFeedback.lightImpact();
    if (mounted) context.pop();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final suggestions = [
      l10n.suggWarranty,
      l10n.suggReturn,
      l10n.suggService,
      l10n.suggInsurance,
      l10n.suggFilter,
    ];

    final possession = ref.watch(possessionByIdProvider(widget.possessionId));

    return Scaffold(
      appBar: AppBar(
        title: EntityContextTitle(
          objectName: possession.value?.title,
          action: l10n.reminderTitle,
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
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.whatIsItLabel,
              hintText: l10n.reminderHint,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() => _title.text = s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.whenLabel),
            child: InkWell(
              onTap: _pickDate,
              child: Text(
                _date == null
                    ? l10n.chooseDate
                    : formatDate(_date!, l10n.localeName),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _date == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.remindMe, style: theme.textTheme.labelLarge),
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
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.noteLabel),
          ),
        ],
      ),
    );
  }
}
