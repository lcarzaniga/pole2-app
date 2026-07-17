import 'document_types.dart';

// Web stub: picking a document from device storage is a native-only feature for
// now, so this is a safe no-op that lets the app compile for web. A pick attempt
// reports back as a silent cancellation.

Future<DocumentResult> pickDocument() async => const DocumentResult.cancelled();
