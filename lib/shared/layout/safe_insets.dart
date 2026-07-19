import 'package:flutter/widgets.dart';

/// The bottom system-navigation inset (the Android three-button bar, or the
/// gesture-navigation pill) that a scroll view must add to its own bottom
/// padding so its **last item scrolls fully above** the system navigation,
/// while a decorative background stays edge-to-edge behind it.
///
/// Uses [MediaQueryData.padding] — the inset *net* of anything already consumed
/// (the keyboard, or a parent `SafeArea`) — so combining it with a `Scaffold`'s
/// `resizeToAvoidBottomInset` never double-counts:
/// - keyboard open  → the keyboard covers the nav area, so this is ~0 and the
///   Scaffold has already lifted the body above the keyboard;
/// - keyboard closed → this is the navigation-bar height;
/// - gesture navigation → this is the small pill inset, added exactly once.
///
/// Never hard-codes a bar height and never disables edge-to-edge.
double safeBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

/// Returns [base] with [safeBottomInset] added to its bottom — intended for a
/// scroll view's `padding`, so the final item (often a primary action) clears
/// the navigation bar. The other edges of [base] are preserved.
EdgeInsets padWithSafeBottom(BuildContext context, EdgeInsets base) =>
    base.copyWith(bottom: base.bottom + safeBottomInset(context));
