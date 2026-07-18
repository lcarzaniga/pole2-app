package com.projectkobe.project_kobe

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts two channels:
 *  - `pole2/installer`: the self-update installer (unchanged).
 *  - `pole2/backup`: Storage Access Framework export for M6.0 — create a
 *    user-chosen document and copy an already-finished, app-private backup file
 *    into it. No storage permission; the backup bytes never travel through the
 *    channel arguments; the copy runs off the main thread.
 */
class MainActivity : FlutterActivity() {
    private val installerChannel = "pole2/installer"
    private val backupChannel = "pole2/backup"
    private val createDocRequest = 4011
    private val openDocRequest = 4012

    private var pendingCreateResult: MethodChannel.Result? = null
    private var pendingOpenResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, installerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canInstall())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("no_path", "path is required", null)
                        } else {
                            try {
                                launchInstaller(path)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("install_failed", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "freeBytes" -> result.success(freeBytes())
                    "createDocument" -> {
                        val name = call.argument<String>("suggestedName") ?: "Pole2.pole2backup"
                        createDocument(name, result)
                    }
                    "copyToUri" -> {
                        val src = call.argument<String>("sourcePath")
                        val uri = call.argument<String>("uri")
                        if (src == null || uri == null) {
                            result.error("bad_args", "sourcePath and uri required", null)
                        } else {
                            copyToUri(src, uri, result)
                        }
                    }
                    "openDocument" -> openDocument(result)
                    "copyUriToFile" -> {
                        val uri = call.argument<String>("uri")
                        val dest = call.argument<String>("destPath")
                        if (uri == null || dest == null) {
                            result.error("bad_args", "uri and destPath required", null)
                        } else {
                            copyUriToFile(uri, dest, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ---- Backup (SAF) ----

    private fun freeBytes(): Long =
        try {
            StatFs(filesDir.path).availableBytes
        } catch (_: Exception) {
            -1L
        }

    private fun createDocument(suggestedName: String, result: MethodChannel.Result) {
        if (pendingCreateResult != null) {
            result.error("busy", "a document creation is already in progress", null)
            return
        }
        pendingCreateResult = result
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/octet-stream"
                putExtra(Intent.EXTRA_TITLE, suggestedName)
            }
            startActivityForResult(intent, createDocRequest)
        } catch (e: Exception) {
            pendingCreateResult = null
            result.error("create_failed", e.message, null)
        }
    }

    private fun openDocument(result: MethodChannel.Result) {
        if (pendingOpenResult != null) {
            result.error("busy", "a document open is already in progress", null)
            return
        }
        pendingOpenResult = result
        try {
            // "*/*" is the practical fallback: many providers don't recognize the
            // custom .pole2backup extension and would otherwise hide the file.
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf("application/octet-stream", "*/*"),
                )
            }
            startActivityForResult(intent, openDocRequest)
        } catch (e: Exception) {
            pendingOpenResult = null
            result.error("open_failed", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            createDocRequest -> {
                val pending = pendingCreateResult
                pendingCreateResult = null
                pending?.success(
                    if (resultCode == Activity.RESULT_OK) data?.data?.toString() else null,
                )
                return
            }
            openDocRequest -> {
                val pending = pendingOpenResult
                pendingOpenResult = null
                pending?.success(
                    if (resultCode == Activity.RESULT_OK) data?.data?.toString() else null,
                )
                return
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun copyUriToFile(uriString: String, destPath: String, result: MethodChannel.Result) {
        // The destination must be inside the app's own private restore staging.
        val dest = File(destPath)
        val canonical = try {
            dest.canonicalPath
        } catch (e: Exception) {
            result.error("bad_dest", e.message, null)
            return
        }
        val allowed = listOf(cacheDir, filesDir).mapNotNull {
            try { it.canonicalPath } catch (_: Exception) { null }
        }
        if (allowed.none { canonical.startsWith(it) }) {
            result.error("bad_dest", "destination not in app storage", null)
            return
        }
        val uri = Uri.parse(uriString)
        Thread {
            var written = 0L
            try {
                dest.parentFile?.mkdirs()
                contentResolver.openInputStream(uri)?.use { input ->
                    dest.outputStream().use { out ->
                        val buf = ByteArray(64 * 1024)
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            out.write(buf, 0, n)
                            written += n
                        }
                        out.flush()
                    }
                } ?: throw IllegalStateException("no input stream")
                if (written <= 0L) throw IllegalStateException("empty document")
                runOnUiThread { result.success(written) }
            } catch (e: Exception) {
                try { if (dest.exists()) dest.delete() } catch (_: Exception) {}
                runOnUiThread { result.error("copy_failed", e.message, null) }
            }
        }.start()
    }

    private fun copyToUri(sourcePath: String, uriString: String, result: MethodChannel.Result) {
        // The source must be an app-private staging file (defense in depth).
        val source = File(sourcePath)
        val canonical = try {
            source.canonicalPath
        } catch (e: Exception) {
            result.error("bad_source", e.message, null)
            return
        }
        val allowed = listOf(cacheDir, filesDir).mapNotNull {
            try { it.canonicalPath } catch (_: Exception) { null }
        }
        if (allowed.none { canonical.startsWith(it) } || !source.exists()) {
            result.error("bad_source", "source not in app storage", null)
            return
        }
        val uri = Uri.parse(uriString)
        Thread {
            var written = 0L
            try {
                contentResolver.openOutputStream(uri)?.use { out ->
                    source.inputStream().use { input ->
                        val buf = ByteArray(64 * 1024)
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            out.write(buf, 0, n)
                            written += n
                        }
                        out.flush()
                    }
                } ?: throw IllegalStateException("no output stream")
                runOnUiThread { result.success(written) }
            } catch (e: Exception) {
                runOnUiThread { result.error("copy_failed", e.message, null) }
            }
        }.start()
    }

    // ---- Installer (unchanged) ----

    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true // pre-O relies on the global "unknown sources" setting
        }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun launchInstaller(path: String) {
        val file = File(path)
        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
