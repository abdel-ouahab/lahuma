package com.lahuma.app.adhan

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * `lahuma/adhan`: turns a downloaded adhan into a `content://` URI that the
 * system can play as a notification-channel sound. A `file://` URI is never
 * used: the system process can't read the app's files through it.
 *
 * Android 10+: the file is copied into MediaStore under
 * `Notifications/Lahuma/`, which the system can always read and which needs
 * no storage permission for the app's own entries.
 * Android 7–9: a FileProvider URI with a read grant to the processes that
 * play notification sounds. Grants don't survive a reboot, so Flutter
 * publishes again on every launch.
 *
 * Dart side: `lib/features/adhan/data/adhan_sound_platform.dart`.
 */
class AdhanSoundChannel(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val context = context.applicationContext
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() = channel.setMethodCallHandler(null)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "exposeSound" -> {
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                if (path == null || name == null) return result.success(null)
                // Copying a few MB: off the main thread.
                Thread {
                    val uri = try {
                        expose(File(path), name)
                    } catch (e: Exception) {
                        Log.w(TAG, "exposeSound failed", e)
                        null
                    }
                    MAIN.post { result.success(uri?.toString()) }
                }.start()
            }
            "removeSounds" -> {
                val keep = call.argument<List<String>>("keep")?.toSet() ?: emptySet()
                Thread {
                    try {
                        removeExcept(keep)
                    } catch (e: Exception) {
                        Log.w(TAG, "removeSounds failed", e)
                    }
                    MAIN.post { result.success(null) }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun expose(file: File, name: String): Uri? {
        if (!file.exists()) return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            exposeMediaStore(file, name)
        } else {
            exposeFileProvider(file, name)
        }
    }

    private fun exposeMediaStore(file: File, name: String): Uri? {
        val resolver = context.contentResolver
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        // Same name, same version: the entry is already there.
        findOwn(name)?.let { return it }
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, name)
            put(MediaStore.Audio.Media.TITLE, name.substringBeforeLast('.'))
            put(MediaStore.Audio.Media.MIME_TYPE, mimeOf(name))
            put(MediaStore.Audio.Media.RELATIVE_PATH, RELATIVE_PATH)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_ALARM, 0)
            put(MediaStore.Audio.Media.IS_RINGTONE, 0)
            put(MediaStore.Audio.Media.IS_MUSIC, 0)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: return null
        try {
            resolver.openOutputStream(uri)?.use { out ->
                file.inputStream().use { it.copyTo(out) }
            } ?: throw IllegalStateException("No output stream")
            resolver.update(uri, ContentValues().apply {
                put(MediaStore.Audio.Media.IS_PENDING, 0)
            }, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        return uri
    }

    /** This app's own MediaStore entry called [name], if any. */
    private fun findOwn(name: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        context.contentResolver.query(
            collection,
            arrayOf(MediaStore.Audio.Media._ID),
            "${MediaStore.Audio.Media.DISPLAY_NAME} = ? AND ${MediaStore.Audio.Media.RELATIVE_PATH} = ?",
            arrayOf(name, RELATIVE_PATH),
            null,
        )?.use { c ->
            if (c.moveToFirst()) return ContentUris.withAppendedId(collection, c.getLong(0))
        }
        return null
    }

    private fun exposeFileProvider(file: File, name: String): Uri {
        // The provider serves filesDir/adhan_sounds (res/xml/adhan_sound_paths.xml).
        val dir = File(context.filesDir, PROVIDER_DIR).apply { mkdirs() }
        val target = File(dir, name)
        if (!target.exists() || target.length() != file.length()) file.copyTo(target, overwrite = true)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.adhan_sounds", target)
        for (pkg in SOUND_PLAYERS) {
            context.grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return uri
    }

    private fun removeExcept(keep: Set<String>) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            // Without storage permission only this app's own entries are visible.
            resolver.query(
                collection,
                arrayOf(MediaStore.Audio.Media._ID, MediaStore.Audio.Media.DISPLAY_NAME),
                "${MediaStore.Audio.Media.RELATIVE_PATH} = ?",
                arrayOf(RELATIVE_PATH),
                null,
            )?.use { c ->
                while (c.moveToNext()) {
                    val name = c.getString(1)
                    if (name.startsWith("adhan_") && name !in keep) {
                        resolver.delete(ContentUris.withAppendedId(collection, c.getLong(0)), null, null)
                    }
                }
            }
        }
        File(context.filesDir, PROVIDER_DIR).listFiles()?.forEach {
            if (it.name !in keep) it.delete()
        }
    }

    private fun mimeOf(name: String) = when (name.substringAfterLast('.').lowercase()) {
        "m4a" -> "audio/mp4"
        "ogg" -> "audio/ogg"
        "wav" -> "audio/wav"
        else -> "audio/mpeg"
    }

    companion object {
        const val NAME = "lahuma/adhan"
        private const val TAG = "AdhanSound"
        private const val RELATIVE_PATH = "Notifications/Lahuma/"
        private const val PROVIDER_DIR = "adhan_sounds"

        /** Processes that read a channel's sound URI (system server, SystemUI). */
        private val SOUND_PLAYERS = listOf("android", "com.android.systemui")
        private val MAIN = android.os.Handler(android.os.Looper.getMainLooper())
    }
}
