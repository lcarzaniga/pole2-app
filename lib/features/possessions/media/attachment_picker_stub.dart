import 'attachment_source.dart';

/// Web/other-platform stub: attachment selection is native-only, so every source
/// is a silent "no picker available".
Future<PickedAttachment> pickAttachment(AttachmentSource source) async =>
    const PickedAttachment.unavailable();
