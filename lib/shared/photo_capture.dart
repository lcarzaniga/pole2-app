import 'package:flutter/material.dart';

import '../app/theme/app_icon_size.dart';
import '../app/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import 'platform/photo_store.dart';

/// The calm capture flow shared by the home "Una foto" action and a dossier's
/// cover photo. It presents a source chooser, captures, and turns every outcome
/// into calm behaviour — never an alarming error, never lost work.

/// Presents the calm source chooser. Returns the chosen [PhotoSource], or null
/// if the user dismissed it (a silent, normal outcome).
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<PhotoSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.photoSourceTitle,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.photoTakePhoto),
            onTap: () => Navigator.of(context).pop(PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.photoChooseGallery),
            onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// The calm, localized message for a capture outcome — or null when nothing
/// should be said (success, or a silent cancellation). Pure so it is unit
/// testable without any platform channels.
String? photoOutcomeMessage(AppLocalizations l10n, PhotoOutcome outcome) =>
    switch (outcome) {
      PhotoOutcome.success => null,
      PhotoOutcome.cancelled => null,
      PhotoOutcome.permissionDenied => l10n.cameraDeniedSnack,
      PhotoOutcome.failed => l10n.captureFailedSnack,
    };

/// Runs the full flow: chooser → capture → returns the stored photo, or null on
/// cancel/denied/failure. Shows a calm snackbar for denied/failed; stays silent
/// on cancel. The caller's own state is never touched, so work is preserved.
Future<StoredPhoto?> chooseAndCapturePhoto(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  final source = await showPhotoSourceSheet(context);
  if (source == null) return null; // dismissed — silent.

  final result = await capturePhoto(source);
  final message = photoOutcomeMessage(l10n, result.outcome);
  if (message != null) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ));
  }
  return result.photo;
}

/// A ready-made "add a photo" leading icon, kept consistent across surfaces.
Icon addPhotoIcon(Color color) =>
    Icon(Icons.add_a_photo_outlined, size: AppIconSize.lg, color: color);
