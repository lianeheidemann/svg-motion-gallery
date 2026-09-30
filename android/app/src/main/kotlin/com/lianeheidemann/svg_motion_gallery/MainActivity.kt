package com.lianeheidemann.svg_motion_gallery

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Gives Flutter what only the activity can do to list the .svg files on the
 * phone: check and request the storage permission, report the storage roots
 * and tell Android's media scanner about changed files. The scanning, reading,
 * writing and deleting themselves happen in Dart (`device_storage_io.dart`).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(hasStorageAccess())
                "requestAccess" -> {
                    requestStorageAccess()
                    result.success(null)
                }
                "roots" -> result.success(storageRoots())
                "scanFile" -> {
                    scanFile(call.arguments as? String)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Android 11+: "All files access"; older: read and write permissions. */
    private fun hasStorageAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            granted(Manifest.permission.READ_EXTERNAL_STORAGE) &&
                granted(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }

    private fun granted(permission: String) =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    /**
     * Android 11+: opens the "All files access" screen of this app (falling
     * back to the general list). Older: shows the runtime prompt. Flutter
     * checks again when the app comes back to the foreground.
     */
    private fun requestStorageAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName"))
                )
            } catch (e: Exception) {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
        } else {
            requestPermissions(
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_REQUEST,
            )
        }
    }

    /** The internal storage plus any SD card, as absolute paths. */
    @Suppress("DEPRECATION")
    private fun storageRoots(): List<String> {
        val roots = linkedSetOf(Environment.getExternalStorageDirectory().absolutePath)
        getExternalFilesDirs(null).filterNotNull().forEach { dir ->
            val path = dir.absolutePath
            val marker = "/Android/data/"
            if (path.contains(marker)) roots.add(path.substringBefore(marker))
        }
        return roots.toList()
    }

    /** Lets other apps (Files, Gallery) notice a file that was changed or deleted. */
    private fun scanFile(path: String?) {
        if (path == null) return
        try {
            MediaScannerConnection.scanFile(applicationContext, arrayOf(path), null, null)
        } catch (e: Exception) {
            // Only the index refresh is skipped; the change itself already happened.
        }
    }

    companion object {
        private const val CHANNEL = "svg_motion_gallery/device_storage"
        private const val STORAGE_REQUEST = 4201
    }
}
