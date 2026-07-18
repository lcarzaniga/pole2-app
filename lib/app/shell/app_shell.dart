import 'package:flutter/material.dart';

import '../../shared/brand/pole_wordmark.dart';

/// The persistent application shell — the calm frame every destination sits in.
///
/// Intentionally minimal for now: a single destination (Home) means a bottom
/// navigation bar would be fake furniture, and restraint forbids it. This
/// widget exists so that when real destinations arrive, they plug into one
/// place (e.g. a `NavigationBar` / `StatefulShellRoute` added here) without
/// reshaping screens.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.body, this.title, this.actions});

  final Widget body;

  /// A plain-text title (e.g. a thing's name). When null, the app bar shows the
  /// Pole² brand wordmark instead — this is the app's own top-level surface.
  final String? title;

  /// Secondary app-bar actions (e.g. the overflow that reaches Archivio).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title == null ? const PoleWordmark(size: 22) : Text(title!),
        actions: actions,
      ),
      body: body,
    );
  }
}
