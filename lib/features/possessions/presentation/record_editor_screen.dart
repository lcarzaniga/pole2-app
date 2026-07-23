import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/daos/evidence_dao.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../../shared/phrasing.dart';
import 'package:path/path.dart' as p;

import '../application/event_providers.dart';
import '../application/possession_providers.dart';
import '../media/attachment_picker.dart';
import '../media/document_pick.dart';
import '../media/document_store.dart';
import '../media/record_flow.dart';
import 'record_category_ui.dart';
import 'widgets/entity_context_title.dart';

/// The M9 contextual-record editor, driven by an always-visible category
/// selector. A plain Nota stays minimal (category + description); any structured
/// category reveals the reference date, validity end, attachments and the opt-in
/// reminder. Switching back to Nota with structured data asks first. Creates a
/// new record when [recordId] is null; edits an existing one otherwise.
class RecordEditorScreen extends ConsumerStatefulWidget {
  const RecordEditorScreen({
    super.key,
    required this.possessionId,
    this.recordId,
  });

  final String possessionId;
  final String? recordId;

  @override
  ConsumerState<RecordEditorScreen> createState() => _RecordEditorScreenState();
}

class _RecordEditorScreenState extends ConsumerState<RecordEditorScreen> {
  final _description = TextEditingController();
  EventKind _kind = EventKind.note;
  DateTime _date = DateTime.now();
  DateTime? _endsAt;
  ReminderLead? _lead;
  bool _saving = false;

  final _newAttachments = <PickedAttachment>[];
  final _removedExisting = <String>{};

  bool get _isEdit => widget.recordId != null;

  /// A structured record (any category other than a plain note) reveals the
  /// optional fields: reference date, validity, attachments and the opt-in
  /// reminder. A plain note keeps only the category selector and the text.
  bool get _isStructured => _kind != EventKind.note;

  /// The saved attachments that are still live (not marked for removal) — read
  /// synchronously so the category-switch safeguard can reason about them.
  List<AttachmentWithFile> get _liveExisting {
    if (!_isEdit) return const [];
    final all =
        ref.read(recordAttachmentsProvider(widget.recordId!)).value ?? const [];
    return [
      for (final a in all)
        if (!_removedExisting.contains(a.evidence.id)) a,
    ];
  }

  /// True when switching to a plain note would drop real structured data —
  /// a validity end, a reminder, or any attachment (new or saved).
  bool get _hasStructuredData =>
      _endsAt != null ||
      _lead != null ||
      _newAttachments.isNotEmpty ||
      _liveExisting.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final event = await ref.read(eventsDaoProvider).getEvent(widget.recordId!);
    if (!mounted || event == null) return;
    setState(() {
      _description.text = event.notes ?? event.title ?? '';
      _kind = event.kind;
      _date = event.at;
      _endsAt = event.endsAt;
      _lead = event.remindLead;
    });
  }

  @override
  void dispose() {
    _description.dispose();
    // Any pending (unsaved) attachment temp files are discarded — nothing was
    // committed, so no orphan is left behind.
    for (final a in _newAttachments) {
      _discard(a);
    }
    super.dispose();
  }

  void _discard(PickedAttachment a) {
    final path = a.tempPath;
    if (path == null) return;
    // Best-effort cleanup of the cached copy; ignore failures.
    discardPickedDocument(path);
  }

  bool get _canSave => _description.text.trim().isNotEmpty && !_saving;

  Future<void> _pickDate({required bool validity}) async {
    final now = DateTime.now();
    final initial = validity ? (_endsAt ?? now) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 100),
    );
    if (picked == null) return;
    setState(() {
      if (validity) {
        _endsAt = picked;
      } else {
        _date = picked;
      }
    });
  }

  /// "Aggiungi allegato": a calm three-option sheet — photograph, choose an
  /// image, or choose a document — then pick and stage-in-memory. A captured or
  /// chosen image gets the default visible label "Foto" (no rename in M9.1).
  Future<void> _addAttachment() async {
    final source = await _showAttachmentSheet();
    if (source == null || !mounted) return; // dismissed — silent.
    var picked = await pickAttachment(source);
    if (!mounted) return;
    if (picked.status == AttachmentPickStatus.picked) {
      if (picked.isImage && (picked.displayName ?? '').trim().isEmpty) {
        picked = picked.withDisplayName(
          AppLocalizations.of(context).attachmentPhotoDefaultLabel,
        );
      }
      setState(() => _newAttachments.add(picked));
      return;
    }
    final msg = attachmentPickMessage(
      AppLocalizations.of(context),
      picked.status,
    );
    if (msg != null) _snack(msg);
  }

  Future<AttachmentSource?> _showAttachmentSheet() {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<AttachmentSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.attachSheetTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.photoTakePhoto),
              onTap: () => Navigator.of(ctx).pop(AttachmentSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.attachChoosePhoto),
              onTap: () => Navigator.of(ctx).pop(AttachmentSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.attachChooseDocument),
              onTap: () => Navigator.of(ctx).pop(AttachmentSource.document),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  /// Selects a category. Switching between structured categories preserves every
  /// entered value. Switching to a plain Nota while structured data exists asks
  /// for a concise confirmation first (cancelling keeps the current category and
  /// all data); nothing is discarded silently.
  Future<void> _selectCategory(EventKind k) async {
    if (k == _kind) return;
    if (k == EventKind.note && _hasStructuredData) {
      final confirmed = await _confirmSwitchToNote();
      if (confirmed != true || !mounted) return;
      setState(() {
        _kind = EventKind.note;
        _endsAt = null;
        _lead = null;
        // Discard staged (never-committed) attachments and mark saved ones for
        // removal on save; the record itself stays until the user saves.
        for (final a in _newAttachments) {
          _discard(a);
        }
        _newAttachments.clear();
        for (final a in _liveExisting) {
          _removedExisting.add(a.evidence.id);
        }
      });
      return;
    }
    setState(() => _kind = k);
  }

  Future<bool?> _confirmSwitchToNote() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.recordSwitchToNoteTitle),
        content: Text(l10n.recordSwitchToNoteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.recordSwitchToNoteConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _openExisting(
    String relativePath,
    String mime,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await openDocument(
      relativePath: relativePath,
      mimeType: mime,
      displayName: name,
    );
    if (!mounted) return;
    final msg = switch (result) {
      DocumentOpenStatus.opened => null,
      DocumentOpenStatus.missing => l10n.documentMissing,
      DocumentOpenStatus.noHandler => l10n.documentOpenNoApp,
      _ => l10n.documentOpenFailed,
    };
    if (msg != null) _snack(msg);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final notes = _description.text.trim();
    // A record's end date only carries a reminder when the user opted in.
    final lead = _endsAt == null ? null : _lead;

    final RecordSaveStatus status;
    if (!_isEdit) {
      status = await saveNewRecord(
        ref,
        possessionId: widget.possessionId,
        kind: _kind,
        at: _date,
        endsAt: _endsAt,
        notes: notes,
        remindLead: lead,
        newAttachments: List.of(_newAttachments),
      );
    } else {
      final id = widget.recordId!;
      await ref
          .read(eventsDaoProvider)
          .updateRecord(
            id,
            kind: _kind,
            at: _date,
            endsAt: _endsAt,
            notes: notes,
            remindLead: lead,
          );
      for (final evId in _removedExisting) {
        await unlinkAttachmentAndReclaim(ref, eventId: id, evidenceId: evId);
      }
      status = await addAttachmentsToRecord(
        ref,
        eventId: id,
        newAttachments: List.of(_newAttachments),
      );
    }

    if (!mounted) return;
    if (status == RecordSaveStatus.saved) {
      // Saved attachments now own their bytes — clear so dispose won't discard.
      _newAttachments.clear();
      HapticFeedback.lightImpact();
      context.pop();
      return;
    }
    setState(() => _saving = false);
    final msg = recordSaveMessage(AppLocalizations.of(context), status);
    if (msg != null) _snack(msg);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final possession = ref.watch(possessionByIdProvider(widget.possessionId));

    final List<AttachmentWithFile> existing = _isEdit
        ? (ref.watch(recordAttachmentsProvider(widget.recordId!)).value ??
              const [])
        : const [];
    final docsPath = ref.watch(appDocumentsPathProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: EntityContextTitle(
          objectName: possession.value?.title,
          action: _isEdit
              ? l10n.recordEditorTitleEdit
              : l10n.recordEditorTitleNew,
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
          // The category selector is always visible and drives the form.
          Text(l10n.recordCategoryLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final k in kRecordCategories)
                ChoiceChip(
                  avatar: Icon(recordCategoryIcon(k), size: 18),
                  label: Text(recordCategoryLabel(l10n, k)),
                  selected: _kind == k,
                  onSelected: (sel) {
                    if (sel) _selectCategory(k);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _description,
            autofocus: !_isEdit,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.recordDescriptionLabel,
              hintText: l10n.recordDescriptionHint,
            ),
          ),
          // Structured categories reveal the optional fields; a plain note keeps
          // only the category selector and the text.
          if (_isStructured) ...[
            const SizedBox(height: AppSpacing.lg),
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.recordReferenceDateLabel,
              ),
              child: InkWell(
                onTap: () => _pickDate(validity: false),
                child: Text(
                  formatDate(_date, l10n.localeName),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _validitySection(context, l10n, theme, scheme),
            const SizedBox(height: AppSpacing.lg),
            _attachmentsSection(context, l10n, theme, existing, docsPath),
          ],
        ],
      ),
    );
  }

  Widget _validitySection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    if (_endsAt == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _pickDate(validity: true),
          icon: const Icon(Icons.event_busy_outlined),
          label: Text(l10n.recordValidityAdd),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.recordValidityLabel,
                ),
                child: InkWell(
                  onTap: () => _pickDate(validity: true),
                  child: Text(
                    '${l10n.recordValidityEndPrefix} '
                    '${formatDate(_endsAt!, l10n.localeName)}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.undo,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _endsAt = null;
                _lead = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.recordRemindMe, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final lead in ReminderLead.values)
              ChoiceChip(
                label: Text(reminderLeadLabel(l10n, lead)),
                selected: _lead == lead,
                onSelected: (sel) => setState(() => _lead = sel ? lead : null),
              ),
          ],
        ),
      ],
    );
  }

  Widget _attachmentsSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    List<AttachmentWithFile> existing,
    String? docsPath,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.recordAttachmentsLabel, style: theme.textTheme.labelLarge),
        for (final att in existing)
          if (!_removedExisting.contains(att.evidence.id))
            AttachmentTile(
              name: att.displayName,
              imagePath:
                  (docsPath != null && att.file.mimeType.startsWith('image/'))
                  ? p.join(docsPath, att.file.relativePath)
                  : null,
              removeTooltip: l10n.documentRemoveTooltip,
              onOpen: () => _openExisting(
                att.file.relativePath,
                att.file.mimeType,
                att.displayName,
              ),
              onRemove: () =>
                  setState(() => _removedExisting.add(att.evidence.id)),
            ),
        for (final a in _newAttachments)
          AttachmentTile(
            name: a.displayName ?? '',
            imagePath: a.isImage ? a.tempPath : null,
            removeTooltip: l10n.documentRemoveTooltip,
            onOpen: () {},
            onRemove: () => setState(() {
              _newAttachments.remove(a);
              _discard(a);
            }),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addAttachment,
            icon: const Icon(Icons.attach_file),
            label: Text(l10n.attachmentAdd),
          ),
        ),
      ],
    );
  }
}
