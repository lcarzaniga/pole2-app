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

/// Where the user records how they got a thing. Everything is optional; saving
/// partial information is always valid. No required-field pressure, no
/// completeness meter — just a calm, single scroll.
class AcquisitionEditorScreen extends ConsumerStatefulWidget {
  const AcquisitionEditorScreen({super.key, required this.possessionId});

  final String possessionId;

  @override
  ConsumerState<AcquisitionEditorScreen> createState() =>
      _AcquisitionEditorScreenState();
}

class _AcquisitionEditorScreenState
    extends ConsumerState<AcquisitionEditorScreen> {
  final _supplier = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();

  AcquisitionType? _type;
  DateTime? _purchasedOn;
  String _currency = 'EUR';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = ref.read(eventsDaoProvider);
    final acq = await dao.watchAcquisition(widget.possessionId).first;
    if (acq != null) {
      _type = acq.acquisitionType;
      _purchasedOn = acq.purchasedOn;
      _currency = acq.currency ?? 'EUR';
      _note.text = acq.notes ?? '';
      if (acq.amountMinor != null) {
        final v = acq.amountMinor! / 100;
        _price.text = v == v.roundToDouble()
            ? v.toStringAsFixed(0)
            : v.toStringAsFixed(2);
      }
      if (acq.partyId != null) {
        final party = await dao.watchParty(acq.partyId!).first;
        _supplier.text = party?.name ?? '';
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _supplier.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _parsePrice() {
    final raw = _price.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final v = double.tryParse(raw);
    if (v == null) return null;
    return (v * 100).round();
  }

  Future<void> _save() async {
    final amount = _parsePrice();
    await ref
        .read(eventsDaoProvider)
        .saveAcquisition(
          possessionId: widget.possessionId,
          type: _type,
          purchasedOn: _purchasedOn,
          supplierName: _supplier.text,
          amountMinor: amount,
          currency: amount == null ? null : _currency,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    HapticFeedback.lightImpact();
    if (mounted) context.pop();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedOn ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
    );
    if (picked != null) setState(() => _purchasedOn = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final possession = ref.watch(possessionByIdProvider(widget.possessionId));

    return Scaffold(
      appBar: AppBar(
        title: EntityContextTitle(
          objectName: possession.value?.title,
          action: l10n.acquisitionTitle,
        ),
        actions: [TextButton(onPressed: _save, child: Text(l10n.saveButton))],
      ),
      body: ListView(
        padding: padWithSafeBottom(
          context,
          const EdgeInsets.all(AppSpacing.lg),
        ),
        children: [
          Text(l10n.howDidYouGetIt, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final t in AcquisitionType.values)
                ChoiceChip(
                  label: Text(acquisitionTypeLabel(l10n, t)),
                  selected: _type == t,
                  onSelected: (s) => setState(() => _type = s ? t : null),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _DateField(
            label: l10n.whenLabel,
            value: _purchasedOn,
            onTap: _pickDate,
            onClear: () => setState(() => _purchasedOn = null),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _supplier,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.whereFromLabel,
              hintText: l10n.whereFromHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.priceLabel),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              DropdownButton<String>(
                value: _currency,
                onChanged: (v) => setState(() => _currency = v ?? 'EUR'),
                items: const [
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                ],
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
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.acquisitionReassure,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable, clearable date row styled like an input.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value == null
            ? const Icon(Icons.calendar_today_outlined)
            : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
      ),
      child: InkWell(
        onTap: onTap,
        child: Text(
          value == null ? l10n.notSet : formatDate(value!, l10n.localeName),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: value == null ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
