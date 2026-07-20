import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_shell.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/brand/pole_wordmark.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../../shared/links/pole2_links.dart';
import '../../../shared/platform/external_link.dart';
import '../application/installed_build.dart';

/// "Informazioni e supporto" — who this app is, which build you are running,
/// where your data lives, and how to reach the public pages.
///
/// A quiet destination on purpose: no animation of its own, no WebView, no
/// account, nothing to configure. It exists so a person can answer "what am I
/// running?" and "how do I ask for help?" without leaving the app confused.
class InformationScreen extends ConsumerWidget {
  const InformationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final installed = ref.watch(installedBuildProvider);

    // The support address carries the installed build; until it is known, the
    // link still works — it simply carries nothing.
    final known = installed.value;
    final version = known?.version;
    final buildNumber = known?.buildNumber;

    return AppShell(
      title: l10n.infoTitle,
      body: HexBackground(
        child: ListView(
          // The last row must clear the system navigation (three-button bar or
          // gesture pill) while the texture stays edge-to-edge behind it.
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
            const _Identity(),
            const SizedBox(height: AppSpacing.lg),
            _VersionLine(installed: installed),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.infoLocalFirst,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.infoLinksTitle),
            const SizedBox(height: AppSpacing.sm),
            for (final row in _rows(l10n))
              _LinkRow(
                icon: row.icon,
                label: row.label,
                subtitle: row.subtitle,
                url: pole2LinkUrl(
                  row.link,
                  version: version,
                  buildNumber: buildNumber,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.infoLinkFootnote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// The five public pages, in the order they are offered.
  List<_Row> _rows(AppLocalizations l10n) => [
    _Row(
      Pole2Link.site,
      Icons.home_outlined,
      l10n.infoLinkSite,
      l10n.infoLinkSiteSub,
    ),
    _Row(
      Pole2Link.guide,
      Icons.menu_book_outlined,
      l10n.infoLinkGuide,
      l10n.infoLinkGuideSub,
    ),
    _Row(
      Pole2Link.news,
      Icons.auto_awesome_outlined,
      l10n.infoLinkNews,
      l10n.infoLinkNewsSub,
    ),
    _Row(
      Pole2Link.support,
      Icons.mail_outline,
      l10n.infoLinkSupport,
      l10n.infoLinkSupportSub,
    ),
    _Row(
      Pole2Link.privacy,
      Icons.lock_outline,
      l10n.infoLinkPrivacy,
      l10n.infoLinkPrivacySub,
    ),
  ];
}

class _Row {
  const _Row(this.link, this.icon, this.label, this.subtitle);
  final Pole2Link link;
  final IconData icon;
  final String label;
  final String subtitle;
}

/// Wordmark + motto: the app saying its own name, once.
class _Identity extends StatelessWidget {
  const _Identity();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The wordmark is decorative here — the app bar already names the
        // screen, so assistive tech hears the brand once, not twice.
        Semantics(
          label: l10n.appName,
          container: true,
          child: const ExcludeSemantics(child: PoleWordmark(size: 34)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.infoSlogan, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

/// "Versione 1.0.16 · build 2021", derived at runtime.
class _VersionLine extends StatelessWidget {
  const _VersionLine({required this.installed});

  final AsyncValue<InstalledBuild> installed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = switch (installed) {
      AsyncValue(:final value?) when value.isKnown => l10n.infoVersion(
        value.version,
        value.buildNumber,
      ),
      // Loading and error read the same on purpose: an unavailable version is
      // not an incident, and there is nothing the user could do about it.
      _ => l10n.infoVersionUnknown,
    };
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One link: icon + text (never colour alone), a ≥48 dp target, and a spoken
/// label that says both the purpose and that it leaves the app.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String url;

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await openExternalUrl(url);
    if (outcome == ExternalLinkOutcome.opened) return;
    // Everything else is a calm sentence, never a red failure.
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          outcome == ExternalLinkOutcome.noHandler
              ? l10n.infoOpenNoBrowser
              : l10n.infoOpenFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      container: true,
      label: l10n.infoLinkSemantics(label),
      // One clean spoken node instead of three fragments (icon, title, subtitle).
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(context),
        child: ConstrainedBox(
          // The whole row is the target, never just the icon.
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.lg),
                // Flexible so long labels at large text sizes wrap instead of
                // overflowing on a 320 dp screen.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // The "leaves the app" affordance, shown as a shape not a hue.
                Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
