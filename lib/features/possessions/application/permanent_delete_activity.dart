import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tiny in-session flag: true while a permanent deletion (single or batch) is
/// running. Storage cleanup (M8.2C) reads it to refuse while a permanent delete
/// is in flight, so the two never race on `photos/` files. Read-only for
/// everyone except the permanent-delete entry points, which bracket their work
/// with [begin]/[end].
final permanentDeleteBusyProvider = NotifierProvider<PermanentDeleteBusy, bool>(
  PermanentDeleteBusy.new,
);

class PermanentDeleteBusy extends Notifier<bool> {
  @override
  bool build() => false;

  void begin() => state = true;
  void end() => state = false;
}
