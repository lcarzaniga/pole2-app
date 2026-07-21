import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_icon_size.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/platform/photo_store.dart';
import '../application/possession_providers.dart';
import '../media/photo_import.dart';
import '../media/photo_import_flow.dart';

/// Create a possession. Deliberately minimal: a title is all that's required,
/// so keeping something takes seconds. Photos, receipts, identifiers and
/// details are all added later — the screen says so, to relieve any pressure
/// to "complete" anything now.
///
/// When reached via the "Una foto" flow, [staged] holds a photo captured into
/// the temporary import area; it is shown as a preview and promoted into
/// `photos/` — bound to the new record — only on Save. Back/cancel discards it,
/// so a cancelled creation now leaves no orphan (M8.2D).
class CreatePossessionScreen extends ConsumerStatefulWidget {
  const CreatePossessionScreen({super.key, this.staged});

  final StagedImport? staged;

  @override
  ConsumerState<CreatePossessionScreen> createState() =>
      _CreatePossessionScreenState();
}

class _CreatePossessionScreenState
    extends ConsumerState<CreatePossessionScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _committed = false; // true once the staged import has been promoted

  @override
  void dispose() {
    // Leaving without a successful save discards the staged import — never based
    // on disposal alone: only when it was never committed.
    final staged = widget.staged;
    if (staged != null && !_committed) {
      discardImport(staged.operationId);
    }
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await createPossessionWithStagedCover(
      ref,
      title: _controller.text.trim(),
      import: widget.staged,
    );

    if (result.status != PhotoSaveStatus.saved) {
      // Blocked or failed: keep the staged photo and the typed title, tell the
      // user calmly, and let them retry. Nothing was created.
      final msg = photoSaveMessage(l10n, result.status);
      if (msg != null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
          );
      }
      if (mounted) setState(() => _saving = false);
      return;
    }

    _committed =
        true; // the import (if any) is now committed — don't discard it
    HapticFeedback.lightImpact();
    // Open the new thing straight away. Replacing this screen keeps the stack
    // clean: Back from the detail returns to Home, not to this form.
    if (mounted) {
      context.pushReplacementNamed(
        Routes.possessionName,
        pathParameters: {'id': result.possessionId!},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.staged != null &&
                  widget.staged!.photos.isNotEmpty) ...[
                _PhotoPreview(
                  relativePath: widget.staged!.photos.first.tempRelativePath,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: l10n.whatIsItLabel,
                  hintText: l10n.createHint,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: AppIconSize.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.createReassure,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(l10n.keepItButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded preview of the staged (temporary) cover photo — the file lives
/// under `photo_imports/` until Save promotes it. Resolves the app docs path
/// lazily; renders nothing on web (no on-disk photo).
class _PhotoPreview extends ConsumerWidget {
  const _PhotoPreview({required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(appDocumentsPathProvider).value;
    if (docs == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: AppRadii.borderMd,
      child: coverImage(
        docsPath: docs,
        relativePath: relativePath,
        height: 180,
      ),
    );
  }
}
