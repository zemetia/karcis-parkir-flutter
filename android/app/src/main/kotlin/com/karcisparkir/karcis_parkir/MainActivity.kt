package com.karcisparkir.karcis_parkir

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.karcisparkir.karcis_parkir/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareDirect" -> {
                    val packages = call.argument<List<String>>("packages") ?: listOf()
                    val filePaths = call.argument<List<String>>("filePaths") ?: listOf()
                    val text = call.argument<String>("text")

                    try {
                        val pm = packageManager
                        var targetPackage: String? = null
                        for (pkg in packages) {
                            try {
                                pm.getPackageInfo(pkg, 0)
                                targetPackage = pkg
                                break
                            } catch (_: Exception) {}
                        }

                        if (targetPackage == null && packages.isNotEmpty()) {
                            // Specified packages are not installed on device
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        val intent = if (filePaths.size > 1) {
                            Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                                val uris = ArrayList<Uri>()
                                for (path in filePaths) {
                                    val f = File(path)
                                    if (f.exists()) {
                                        val uri = FileProvider.getUriForFile(
                                            this@MainActivity,
                                            "${applicationContext.packageName}.fileprovider",
                                            f
                                        )
                                        uris.add(uri)
                                    }
                                }
                                putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                                type = "image/*"
                            }
                        } else if (filePaths.size == 1) {
                            Intent(Intent.ACTION_SEND).apply {
                                val f = File(filePaths[0])
                                val uri = FileProvider.getUriForFile(
                                    this@MainActivity,
                                    "${applicationContext.packageName}.fileprovider",
                                    f
                                )
                                putExtra(Intent.EXTRA_STREAM, uri)
                                type = "image/*"
                            }
                        } else {
                            Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                            }
                        }

                        if (!text.isNullOrEmpty()) {
                            intent.putExtra(Intent.EXTRA_TEXT, text)
                        }
                        if (targetPackage != null) {
                            intent.setPackage(targetPackage)
                        }
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_DIRECT_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
