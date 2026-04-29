package com.example.my_password

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
    private val exportDirectoryChannel = "my_password/export_directory"
    private var pendingDirectoryResult: MethodChannel.Result? = null
    private var pendingBackupFileResult: MethodChannel.Result? = null

    private val directoryPicker =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val methodResult = pendingDirectoryResult
            pendingDirectoryResult = null

            if (methodResult == null) {
                return@registerForActivityResult
            }

            if (result.resultCode != Activity.RESULT_OK) {
                methodResult.success(null)
                return@registerForActivityResult
            }

            val uri = result.data?.data
            if (uri == null) {
                methodResult.success(null)
                return@registerForActivityResult
            }

            val flags =
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            contentResolver.takePersistableUriPermission(uri, flags)

            methodResult.success(
                mapOf(
                    "uri" to uri.toString(),
                    "label" to buildDirectoryLabel(uri),
                ),
            )
        }

    private val backupFilePicker =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val methodResult = pendingBackupFileResult
            pendingBackupFileResult = null

            if (methodResult == null) {
                return@registerForActivityResult
            }

            if (result.resultCode != Activity.RESULT_OK) {
                methodResult.success(null)
                return@registerForActivityResult
            }

            val uri = result.data?.data
            if (uri == null) {
                methodResult.success(null)
                return@registerForActivityResult
            }

            try {
                val fileName = queryFileName(uri) ?: "backup_import.mpbak"
                val targetFile = File(cacheDir, fileName)
                contentResolver.openInputStream(uri)?.use { input ->
                    targetFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                } ?: throw IOException("Unable to open selected backup file")

                methodResult.success(
                    mapOf(
                        "path" to targetFile.absolutePath,
                        "label" to fileName,
                    ),
                )
            } catch (error: Exception) {
                methodResult.error("pick_backup_failed", error.message, null)
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exportDirectoryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> pickDirectory(result)
                    "pickBackupFile" -> pickBackupFile(result)
                    "writeBackupFile" -> writeBackupFile(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingDirectoryResult != null) {
            result.error("busy", "Directory picker already active", null)
            return
        }

        pendingDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        directoryPicker.launch(intent)
    }

    private fun pickBackupFile(result: MethodChannel.Result) {
        if (pendingBackupFileResult != null) {
            result.error("busy", "Backup picker already active", null)
            return
        }

        pendingBackupFileResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        backupFilePicker.launch(intent)
    }

    private fun writeBackupFile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val directoryUri = call.argument<String>("directoryUri")
            val fileName = call.argument<String>("fileName")
            val bytes = call.argument<ByteArray>("bytes")

            if (directoryUri.isNullOrEmpty() || fileName.isNullOrEmpty() || bytes == null) {
                result.error("invalid_args", "Missing backup export arguments", null)
                return
            }

            val treeUri = Uri.parse(directoryUri)
            val directory = DocumentFile.fromTreeUri(this, treeUri)
            if (directory == null || !directory.canWrite()) {
                result.error("not_writable", "Directory is not writable", null)
                return
            }

            directory.findFile(fileName)?.delete()
            val document = directory.createFile("application/octet-stream", fileName)
            if (document == null) {
                result.error("create_failed", "Unable to create backup file", null)
                return
            }

            contentResolver.openOutputStream(document.uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IOException("Unable to open backup output stream")

            result.success(
                mapOf(
                    "uri" to document.uri.toString(),
                    "label" to fileName,
                ),
            )
        } catch (error: Exception) {
            result.error("write_failed", error.message, null)
        }
    }

    private fun buildDirectoryLabel(uri: Uri): String {
        val documentId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            android.provider.DocumentsContract.getTreeDocumentId(uri)
        } else {
            uri.lastPathSegment
        }
        return documentId?.substringAfterLast(':') ?: uri.toString()
    }

    private fun queryFileName(uri: Uri): String? {
        contentResolver.query(
            uri,
            arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (index >= 0) {
                    return cursor.getString(index)
                }
            }
        }
        return null
    }
}
