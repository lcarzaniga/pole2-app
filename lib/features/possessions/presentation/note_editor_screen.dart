import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/event_providers.dart';
import '../application/possession_providers.dart';
import 'widgets/entity_context_title.dart';

/// Write a free-text note attached to a thing. The note is all that's needed —
/// a single field, saved to the thing's timeline. The owning object stays
/// visible in the app bar so the note is never a context-less scrap.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.possessionId});

  final String possessionId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _body = TextEditingController();

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _canSave => _body.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    await ref.read(eventsDaoProvider).createNote(
          possessionId: widget.possessionId,
          body: _body.text.trim(),
        );
    HapticFeedback.lightImpact();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final possession = ref.watch(possessionByIdProvider(widget.possessionId));

    return Scaffold(
      appBar: AppBar(
        title: EntityContextTitle(
          objectName: possession.value?.title,
          action: l10n.noteEditorTitle,
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
          TextField(
            controller: _body,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.noteLabel,
              hintText: l10n.noteHint,
            ),
          ),
        ],
      ),
    );
  }
}
