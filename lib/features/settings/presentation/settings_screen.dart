import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme/app_icon_size.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/platform/distribution.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../information/application/installed_build.dart';
import '../application/language_preference.dart';
import 'update_check.dart';

/// "Impostazioni" — the one place where Pole² is configured.
///
/// Deliberately a *hub*, not a junk drawer: the only things implemented here are
/// the language choice and the manual update check. Data/space and
/// information/support are existing destinations that this screen simply leads
/// to, so nothing is duplicated and every row does something real.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final distribution = ref.watch(distributionProvider);

    return AppShell(
      title: l10n.settingsTitle,
      body: HexBackground(
        child: ListView(
          padding: padWithSafeBottom(
            context,
            const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
          ),
          children: [
            _SectionLabel(l10n.settingsLanguageSection),
            const SizedBox(height: AppSpacing.sm),
            const _LanguageSection(),

            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.settingsDataSection),
            const SizedBox(height: AppSpacing.sm),
            _SettingsRow(
              icon: Icons.inventory_2_outlined,
              label: l10n.settingsDataRow,
              subtitle: l10n.settingsDataRowSub,
              onTap: () => context.pushNamed(Routes.backupName),
            ),

            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.settingsUpdatesSection),
            const SizedBox(height: AppSpacing.sm),
            const _InstalledVersionRow(),
            // Play builds must never offer a self-installed APK; the store owns
            // updates there. Direct builds keep today's behaviour untouched.
            if (distribution.allowsSelfUpdate)
              const UpdateCheckRow()
            else
              _SettingsNote(l10n.settingsUpdateManagedByStore),

            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.settingsInfoSection),
            const SizedBox(height: AppSpacing.sm),
            _SettingsRow(
              icon: Icons.info_outline,
              label: l10n.settingsInfoRow,
              subtitle: l10n.settingsInfoRowSub,
              onTap: () => context.pushNamed(Routes.informationName),
            ),
          ],
        ),
      ),
    );
  }
}

/// The language choice: three options, always visible, applied the moment they
/// are chosen — no dialog, no sub-screen, no confirmation, no restart.
class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(languagePreferenceProvider);
    final scheme = Theme.of(context).colorScheme;

    void choose(AppLanguage? next) {
      if (next == null) return;
      ref.read(languagePreferenceProvider.notifier).set(next);
    }

    // A Material (not a decorated Container): ListTile paints its ink on the
    // nearest Material ancestor, so a coloured box in between would swallow the
    // splash. Same rounded surface, working touch feedback.
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadii.borderLg,
      clipBehavior: Clip.antiAlias,
      child: RadioGroup<AppLanguage>(
        groupValue: current,
        onChanged: choose,
        child: Column(
          children: [
            RadioListTile<AppLanguage>(
              value: AppLanguage.auto,
              title: Text(l10n.languageAuto),
              subtitle: Text(l10n.languageAutoSubtitle),
            ),
            RadioListTile<AppLanguage>(
              value: AppLanguage.it,
              title: Text(l10n.languageItalian),
            ),
            RadioListTile<AppLanguage>(
              value: AppLanguage.en,
              title: Text(l10n.languageEnglish),
            ),
          ],
        ),
      ),
    );
  }
}

/// The version actually installed, read at runtime so it can never drift.
class _InstalledVersionRow extends ConsumerWidget {
  const _InstalledVersionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final installed = ref.watch(installedBuildProvider);
    final value = switch (installed) {
      AsyncValue(:final value?) when value.isKnown => l10n.infoVersion(
        value.version,
        value.buildNumber,
      ),
      _ => l10n.infoVersionUnknown,
    };
    return _SettingsRow(
      icon: Icons.tag_outlined,
      label: l10n.settingsInstalledVersion,
      subtitle: value,
      onTap: null,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A quiet, non-actionable line (e.g. "updates come from the Play Store").
class _SettingsNote extends StatelessWidget {
  const _SettingsNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One settings row. With [onTap] null it is a calm read-only line (no ripple,
/// no chevron) — used for the installed version.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.md, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: AppIconSize.md,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadii.borderLg,
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
