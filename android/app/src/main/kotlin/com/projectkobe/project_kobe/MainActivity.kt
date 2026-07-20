package com.projectkobe.project_kobe

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.util.PathUtils
import java.io.File

/**
 * Hosts three channels:
 *  - `pole2/installer`: the self-update installer (unchanged).
 *  - `pole2/backup`: Storage Access Framework export for M6.0 — create a
 *    user-chosen document and copy an already-finished, app-private backup file
 *    into it. No storage permission; the backup bytes never travel through the
 *    channel arguments; the copy runs off the main thread.
 *  - `pole2/links`: opens a canonical Pole² https page in the user's own
 *    browser (M7.3B). Exact-host allowlist, no permission, no WebView.
 */
class MainActivity : FlutterActivity() {
    private val installerChannel = "pole2/installer"
    private val backupChannel = "pole2/backup"
    private val linksChannel = "pole2/links"
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
                    "closeForRestore" -> closeForRestore(call.argument<String>("token"), result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, linksChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            result.error("bad_args", "url is required", null)
                        } else {
                            openExternal(url, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ---- External links ----

    /**
     * Opens a canonical Pole² page in whatever browser the user already uses.
     *
     * Re-validates the URL **independently of Dart** (same rule as
     * `isAllowedPole2Url`) so a bug or a future caller on the Dart side cannot
     * alone turn this channel into an open redirector: exact host, https only,
     * no embedded credentials, default port only. `CATEGORY_BROWSABLE` keeps
     * the intent to things that genuinely display web pages.
     */
    private fun openExternal(url: String, result: MethodChannel.Result) {
        val uri = try { Uri.parse(url) } catch (_: Exception) { null }
        val allowed = uri != null &&
            uri.isAbsolute &&
            "https".equals(uri.scheme, ignoreCase = true) &&
            uri.userInfo == null &&
            "pole2.app".equals(uri.host, ignoreCase = true) &&
            (uri.port == -1 || uri.port == 443)
        if (!allowed) {
            // Never log the URL itself.
            result.error("rejected", "Only canonical https Pole² links may be opened", null)
            return
        }
        val intent = Intent(Intent.ACTION_VIEW, uri)
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
            result.success(true)
        } catch (_: android.content.ActivityNotFoundException) {
            result.error("no_handler", "No browser is available on this device", null)
        } catch (e: Exception) {
            result.error("open_failed", e.javaClass.simpleName, null)
        }
    }

    // ---- Backup (SAF) ----

    /**
     * Deliberately terminates the app for the restore-restart flow. Runs on the
     * main thread: finishes and removes the task, then kills our own process so
     * the Dart VM / provider container cannot linger (SystemNavigator.pop /
     * Dart exit(0) alone proved insufficient on some devices). Gated by a
     * non-secret token so it can only be reached from that deliberate flow;
     * callers must already have written the durable pending marker.
     */
    private fun closeForRestore(token: String?, result: MethodChannel.Result) {
        if (token != "restore-restart") {
            result.error("bad_token", "closeForRestore requires the restore-restart token", null)
            return
        }
        runOnUiThread {
            try {
                finishAndRemoveTask()
            } catch (_: Exception) {
                try { finishAffinity() } catch (_: Exception) {}
            }
            // The process ends here; the pending Dart result never resolves,
            // which is the intended "we actually closed" outcome.
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }

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
                // The copy happens immediately, so a transient read grant is
                // enough; we never take a persistable permission.
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
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

    /**
     * The set of app-private roots a staging path may live under. Includes
     * Flutter's official data directory (`app_flutter`), which is what
     * `getApplicationDocumentsDirectory()` returns on Android — a sibling of
     * `files`/`cache`, so a `files`/`cache`-only allowlist wrongly rejects it.
     * Resolved to canonical paths so `../` and symlink escapes can't slip past.
     */
    private fun approvedRoots(): List<String> =
        listOfNotNull(cacheDir, filesDir, dataDirectoryOrNull())
            .mapNotNull { try { it.canonicalPath } catch (_: Exception) { null } }

    private fun dataDirectoryOrNull(): File? =
        try { File(PathUtils.getDataDirectory(applicationContext)) } catch (_: Exception) { null }

    /**
     * Canonical containment with a path-separator boundary: accepts the root
     * itself and its descendants, rejects similarly-prefixed siblings
     * (e.g. `/data/.../filesX` under `/data/.../files`). [canonicalPath] must
     * already be canonicalized by the caller.
     */
    private fun isInsideApprovedRoot(canonicalPath: String): Boolean =
        approvedRoots().any { root ->
            canonicalPath == root || canonicalPath.startsWith(root + File.separator)
        }

    private val isDebuggable: Boolean
        get() = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

    /** Debug-only diagnostic — never logs the full URI, path, contents or secrets. */
    private fun copyDiag(stage: String, uri: Uri, e: Throwable?, written: Long, dest: File) {
        if (!isDebuggable) return
        val destRoot = try {
            val c = dest.canonicalPath
            when {
                c.startsWith(cacheDir.canonicalPath) -> "cache"
                c.startsWith(filesDir.canonicalPath) -> "files"
                else -> "app_flutter"
            }
        } catch (_: Exception) { "unknown" }
        Log.d(
            "Pole2Restore",
            "stage=$stage scheme=${uri.scheme} provider=${uri.authority} " +
                "err=${e?.javaClass?.simpleName} written=$written destRoot=$destRoot",
        )
    }

    private fun copyUriToFile(uriString: String, destPath: String, result: MethodChannel.Result) {
        // The destination must be inside the app's own private storage.
        val dest = File(destPath)
        val canonical = try {
            dest.canonicalPath
        } catch (e: Exception) {
            result.error("bad_dest", "invalid destination", null)
            return
        }
        if (!isInsideApprovedRoot(canonical)) {
            result.error("bad_dest", "destination not in app storage", null)
            return
        }
        val uri = Uri.parse(uriString)
        Thread {
            var written = 0L
            val input = try {
                contentResolver.openInputStream(uri)
            } catch (e: SecurityException) {
                copyDiag("open", uri, e, 0L, dest)
                runOnUiThread { result.error("open_denied", "no access to the selected file", null) }
                return@Thread
            } catch (e: Exception) {
                copyDiag("open", uri, e, 0L, dest)
                runOnUiThread { result.error("open_failed", "could not open the selected file", null) }
                return@Thread
            }
            if (input == null) {
                copyDiag("open", uri, null, 0L, dest)
                runOnUiThread { result.error("open_failed", "could not open the selected file", null) }
                return@Thread
            }
            try {
                dest.parentFile?.mkdirs()
                input.use { inp ->
                    dest.outputStream().use { out ->
                        val buf = ByteArray(64 * 1024)
                        while (true) {
                            val n = inp.read(buf)
                            if (n < 0) break
                            out.write(buf, 0, n)
                            written += n
                        }
                        out.flush()
                    }
                }
            } catch (e: Exception) {
                copyDiag("copy", uri, e, written, dest)
                try { if (dest.exists()) dest.delete() } catch (_: Exception) {}
                runOnUiThread { result.error("copy_io_failed", "could not read the selected file", null) }
                return@Thread
            }
            if (written <= 0L) {
                try { if (dest.exists()) dest.delete() } catch (_: Exception) {}
                runOnUiThread { result.error("empty_document", "the selected file is empty", null) }
                return@Thread
            }
            runOnUiThread { result.success(written) }
        }.start()
    }

    private fun copyToUri(sourcePath: String, uriString: String, result: MethodChannel.Result) {
        // The source must be an app-private staging file (defense in depth).
        val source = File(sourcePath)
        val canonical = try {
            source.canonicalPath
        } catch (e: Exception) {
            result.error("bad_source", "invalid source", null)
            return
        }
        if (!isInsideApprovedRoot(canonical) || !source.exists()) {
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
                runOnUiThread { result.error("copy_failed", "could not write the backup", null) }
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
