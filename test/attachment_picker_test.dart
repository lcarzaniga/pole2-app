import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:project_kobe/features/possessions/media/attachment_picker.dart';

/// M9.1 — the common attachment picker: camera/gallery go through image_picker
/// with the evidence profile (3000 px / q90 / no full metadata), documents keep
/// the SAF delegation. Every outcome is data, never an exception. The
/// image_picker platform is faked so no device is needed.
class _FakeImagePicker extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  XFile? Function()? onGet;
  Object? throwError;
  ImageSource? lastSource;
  ImagePickerOptions? lastOptions;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    lastSource = source;
    lastOptions = options;
    if (throwError != null) throw throwError!;
    return onGet?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeImagePicker fake;
  late Directory dir;

  setUp(() {
    fake = _FakeImagePicker();
    ImagePickerPlatform.instance = fake;
    dir = Directory.systemTemp.createTempSync('pole2_ap_');
  });
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  File tmpImage(int bytes) =>
      File('${dir.path}/cap.jpg')..writeAsBytesSync(List.filled(bytes, 1));

  group('camera / gallery capture', () {
    test(
      'camera success returns a JPEG photo with the evidence profile',
      () async {
        final f = tmpImage(1234);
        fake.onGet = () => XFile(f.path);

        final r = await pickAttachment(AttachmentSource.camera);

        expect(r.status, AttachmentPickStatus.picked);
        expect(r.kind, EvidenceKind.photo);
        expect(r.mimeType, 'image/jpeg');
        expect(r.isImage, isTrue);
        expect(r.displayName, isNull); // caller applies the localized "Foto"
        expect(r.tempPath, f.path);
        expect(r.byteSize, 1234);
        // The evidence profile — deliberately higher than the cover (2400/85).
        expect(fake.lastSource, ImageSource.camera);
        expect(fake.lastOptions!.maxWidth, 3000);
        expect(fake.lastOptions!.maxHeight, 3000);
        expect(fake.lastOptions!.imageQuality, 90);
        expect(fake.lastOptions!.requestFullMetadata, isFalse);
      },
    );

    test('gallery routes to the gallery source', () async {
      final f = tmpImage(10);
      fake.onGet = () => XFile(f.path);
      final r = await pickAttachment(AttachmentSource.gallery);
      expect(r.status, AttachmentPickStatus.picked);
      expect(fake.lastSource, ImageSource.gallery);
      expect(r.kind, EvidenceKind.photo);
    });

    test('cancellation is a silent cancelled outcome', () async {
      fake.onGet = () => null;
      final r = await pickAttachment(AttachmentSource.camera);
      expect(r.status, AttachmentPickStatus.cancelled);
      expect(r.tempPath, isNull);
    });

    test('a denied camera permission maps to permissionDenied', () async {
      fake.throwError = PlatformException(code: 'camera_access_denied');
      final r = await pickAttachment(AttachmentSource.camera);
      expect(r.status, AttachmentPickStatus.permissionDenied);
    });

    test('a denied photo permission maps to permissionDenied', () async {
      fake.throwError = PlatformException(code: 'photo_access_denied');
      final r = await pickAttachment(AttachmentSource.gallery);
      expect(r.status, AttachmentPickStatus.permissionDenied);
    });

    test('any other error maps to failed', () async {
      fake.throwError = PlatformException(code: 'boom');
      final r = await pickAttachment(AttachmentSource.camera);
      expect(r.status, AttachmentPickStatus.failed);
    });

    test('an empty captured file is unreadable', () async {
      final f = tmpImage(0);
      fake.onGet = () => XFile(f.path);
      final r = await pickAttachment(AttachmentSource.camera);
      expect(r.status, AttachmentPickStatus.unreadable);
    });
  });

  group('document delegation', () {
    test(
      'document source delegates to SAF (unavailable without a channel)',
      () async {
        // No pole2/documents handler in the test env → the SAF facade reports
        // "no picker available", proving delegation (not an image_picker call).
        final r = await pickAttachment(AttachmentSource.document);
        expect(r.status, AttachmentPickStatus.unavailable);
        expect(fake.lastSource, isNull); // image_picker was NOT invoked
      },
    );
  });

  group('PickedAttachment value type', () {
    test('isImage + withDisplayName', () {
      const img = PickedAttachment.picked(
        tempPath: '/t/x.jpg',
        mimeType: 'image/jpeg',
        byteSize: 3,
        kind: EvidenceKind.photo,
      );
      expect(img.isImage, isTrue);
      expect(img.withDisplayName('Foto').displayName, 'Foto');
      expect(img.withDisplayName('Foto').kind, EvidenceKind.photo);

      const pdf = PickedAttachment.picked(
        tempPath: '/t/x.pdf',
        mimeType: 'application/pdf',
        byteSize: 3,
        kind: EvidenceKind.other,
      );
      expect(pdf.isImage, isFalse);
      expect(
        const PickedAttachment.cancelled().status,
        AttachmentPickStatus.cancelled,
      );
    });
  });
}
