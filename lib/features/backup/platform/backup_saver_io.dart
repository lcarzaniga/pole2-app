import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('pole2/backup');

/// Backup save is supported only on Android in M6.0.
Future<bool> backupSupported() async => Platform.isAndroid;

/// Free bytes available where the app stores its data (StatFs), for the export
/// preflight. Null if it can't be determined.
Future<int?> freeBytesForBackup() async {
  if (!Platform.isAndroid) return null;
  try {
    final v = await _channel.invokeMethod<int>('freeBytes');
    return v;
  } catch (_) {
    return null;
  }
}

/// Opens the system "create document" picker with [suggestedName]. Returns the
/// chosen `content://` URI, or null if the user cancelled (a normal no-op).
Future<String?> createBackupDocument(String suggestedName) async {
  if (!Platform.isAndroid) return null;
  return _channel.invokeMethod<String>('createDocument', {
    'suggestedName': suggestedName,
  });
}

/// Copies [sourcePath] (an app-private file) into the [uri] the user chose.
/// Native validates the source is inside the app's own storage and streams the
/// copy off the main thread. Returns the number of bytes written.
Future<int> copyFileToUri({
  required String sourcePath,
  required String uri,
}) async {
  final written = await _channel.invokeMethod<int>('copyToUri', {
    'sourcePath': sourcePath,
    'uri': uri,
  });
  return written ?? 0;
}

/// Opens the system "open document" picker (M6.1 restore). Returns the chosen
/// `content://` URI, or null if the user cancelled.
Future<String?> openBackupDocument() async {
  if (!Platform.isAndroid) return null;
  return _channel.invokeMethod<String>('openDocument');
}

/// Streams the chosen [uri] into [destPath] (must be inside app-private restore
/// staging). Returns bytes copied; native rejects a zero-byte/incomplete copy.
Future<int> copyUriToFile({
  required String uri,
  required String destPath,
}) async {
  final written = await _channel.invokeMethod<int>('copyUriToFile', {
    'uri': uri,
    'destPath': destPath,
  });
  return written ?? 0;
}
