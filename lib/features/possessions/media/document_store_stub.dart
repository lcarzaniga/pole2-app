import 'document_pick.dart';

/// Web/other-platform stub: document selection is native-only, so picking is a
/// silent "no picker available".
Future<PickedDocument> pickDocument() async =>
    const PickedDocument.unavailable();

Future<DocumentOpenStatus> openDocument({
  required String relativePath,
  required String mimeType,
  String? displayName,
}) async => DocumentOpenStatus.unavailable;

void discardPickedDocument(String tempPath) {}
