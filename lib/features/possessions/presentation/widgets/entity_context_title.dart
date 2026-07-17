import 'package:flutter/material.dart';

/// A two-line app-bar title that keeps the owning object visible while the user
/// edits or views a related entity (a note, a date, an acquisition, …). The
/// object's name leads; the action is a quiet second line. Used everywhere a
/// related editor would otherwise be a context-less generic form.
class EntityContextTitle extends StatelessWidget {
  const EntityContextTitle({
    super.key,
    required this.objectName,
    required this.action,
  });

  /// The possession this entity belongs to. May be null while it resolves.
  final String? objectName;

  /// What the user is doing here (e.g. "Aggiungi una nota").
  final String action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = objectName;
    // Until the name resolves, show only the action — never an empty gap.
    if (name == null || name.isEmpty) {
      return Text(action);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name,
            style: theme.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(action,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
