import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_icon_size.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/platform/photo_store.dart';
import '../application/possession_providers.dart';

/// Create a possession. Deliberately minimal: a title is all that's required,
/// so keeping something takes seconds. Photos, receipts, identifiers and
/// details are all added later — the screen says so, to relieve any pressure
/// to "complete" anything now.
///
/// When reached via the "Una foto" flow, [initialPhoto] holds a photo already
/// captured and stored on disk; it is shown as a cover preview and attached to
/// the new record on save.
class CreatePossessionScreen extends ConsumerStatefulWidget {
  const CreatePossessionScreen({super.key, this.initialPhoto});

  final StoredPhoto? initialPhoto;

  @override
  ConsumerState<CreatePossessionScreen> createState() =>
      _CreatePossessionScreenState();
}

class _CreatePossessionScreenState
    extends ConsumerState<CreatePossessionScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final dao = ref.read(possessionsDaoProvider);
    final created = await dao.createPossession(title: _controller.text.trim());
    // Attach the already-captured photo, if the user came via "Una foto".
    final photo = widget.initialPhoto;
    if (photo != null) {
      await dao.setCover(
        created.id,
        relativePath: photo.relativePath,
        mimeType: photo.mimeType,
        byteSize: photo.byteSize,
      );
    }
    // A single gentle confirmation — definitive, never celebratory.
    HapticFeedback.lightImpact();
    if (mounted) context.pop();
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
              if (widget.initialPhoto != null) ...[
                _PhotoPreview(photo: widget.initialPhoto!),
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
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

/// A rounded preview of the just-captured cover photo. Resolves the app docs
/// path lazily; renders nothing on web (no on-disk photo).
class _PhotoPreview extends ConsumerWidget {
  const _PhotoPreview({required this.photo});

  final StoredPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(appDocumentsPathProvider).value;
    if (docs == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: AppRadii.borderMd,
      child: coverImage(
        docsPath: docs,
        relativePath: photo.relativePath,
        height: 180,
      ),
    );
  }
}
