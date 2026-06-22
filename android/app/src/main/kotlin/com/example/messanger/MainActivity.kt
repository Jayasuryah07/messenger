package com.example.messanger

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import android.content.ClipboardManager
import android.content.ClipData
import android.content.Context
import android.widget.Toast

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.messanger/whatsapp_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareFile") {
                val filePath = call.argument<String>("filePath")
                val phone = call.argument<String>("phone")
                val text = call.argument<String>("text")
                if (filePath != null && phone != null) {
                    val success = shareFileToWhatsApp(filePath, phone, text ?: "")
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENTS", "filePath or phone is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun shareFileToWhatsApp(filePath: String, phone: String, text: String): Boolean {
        val file = File(filePath)
        if (!file.exists()) return false
        
        try {
            val fileUri: Uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.provider",
                file
            )

            val pm = context.packageManager
            var whatsappPackage = ""
            
            // Try to resolve the default app for whatsapp scheme to respect user's default app preference
            try {
                val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse("whatsapp://send"))
                val resolveInfo = pm.resolveActivity(viewIntent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
                val resolvedPkg = resolveInfo?.activityInfo?.packageName
                if (resolvedPkg == "com.whatsapp" || resolvedPkg == "com.whatsapp.w4b") {
                    whatsappPackage = resolvedPkg
                }
            } catch (e: Exception) {
                // Ignore and fall back to manual checks
            }
            
            if (whatsappPackage.isEmpty()) {
                try {
                    pm.getPackageInfo("com.whatsapp", 0)
                    whatsappPackage = "com.whatsapp"
                } catch (e: Exception) {
                    try {
                        pm.getPackageInfo("com.whatsapp.w4b", 0)
                        whatsappPackage = "com.whatsapp.w4b"
                    } catch (ex: Exception) {
                        return false
                    }
                }
            }

            var cleanPhone = phone.replace(Regex("[^\\d]"), "")
            if (cleanPhone.length == 10) {
                cleanPhone = "91$cleanPhone"
            }

            val isPdf = filePath.endsWith(".pdf", ignoreCase = true)
            if (isPdf && text.isNotEmpty()) {
                try {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = ClipData.newPlainText("WhatsApp Message", text)
                    clipboard.setPrimaryClip(clip)
                    Toast.makeText(context, "Message copied! Paste it in the WhatsApp chat.", Toast.LENGTH_LONG).show()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = if (isPdf) "application/pdf" else when {
                    filePath.endsWith(".jpg", ignoreCase = true) || 
                    filePath.endsWith(".jpeg", ignoreCase = true) || 
                    filePath.endsWith(".png", ignoreCase = true) -> "image/*"
                    else -> "*/*"
                }
                putExtra(Intent.EXTRA_STREAM, fileUri)
                putExtra("jid", "$cleanPhone@s.whatsapp.net")
                putExtra(Intent.EXTRA_TEXT, text)
                setPackage(whatsappPackage)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(intent)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}
