package com.towhid.expense_tracker

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.widget.Toast
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the biometric prompt.
class MainActivity : FlutterFragmentActivity() {
    private val otaChannel = "com.towhid.expense_tracker/ota"
    private var downloadReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, otaChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVersionCode" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                        info.longVersionCode.toInt() else @Suppress("DEPRECATION") info.versionCode
                    result.success(code)
                }
                "getVersionName" -> {
                    result.success(packageManager.getPackageInfo(packageName, 0).versionName ?: "?")
                }
                "downloadAndInstall" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName") ?: "ExpenseTracker-update.apk"
                    if (url == null) {
                        result.error("BAD_ARGS", "url is required", null)
                    } else {
                        downloadAndInstall(url, fileName)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Downloads the APK with the system DownloadManager (shows a progress
    // notification) and opens the package installer when it finishes.
    private fun downloadAndInstall(url: String, fileName: String) {
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

        // A stale receiver from a previous attempt would fire twice.
        downloadReceiver?.let { runCatching { unregisterReceiver(it) } }

        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(fileName)
            .setDescription("Downloading app update")
            .setMimeType("application/vnd.android.package-archive")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, fileName)
        val downloadId = dm.enqueue(request)

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L) != downloadId) return
                runCatching { context.unregisterReceiver(this) }
                downloadReceiver = null

                val apkUri = dm.getUriForDownloadedFile(downloadId)
                if (apkUri == null) {
                    Toast.makeText(context, "Update download failed", Toast.LENGTH_LONG).show()
                    return
                }
                val install = Intent(Intent.ACTION_VIEW)
                    .setDataAndType(apkUri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                runCatching { context.startActivity(install) }
                    .onFailure { Toast.makeText(context, "Could not open installer", Toast.LENGTH_LONG).show() }
            }
        }
        downloadReceiver = receiver

        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    override fun onDestroy() {
        downloadReceiver?.let { runCatching { unregisterReceiver(it) } }
        downloadReceiver = null
        super.onDestroy()
    }
}
