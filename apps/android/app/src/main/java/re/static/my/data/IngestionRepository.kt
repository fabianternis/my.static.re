package re.static.my.data

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import kotlinx.coroutines.flow.first
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class IngestionRepository(
    private val context: Context,
    private val configManager: AppConfigManager,
    private val apiService: ApiService
) {
    suspend fun uploadUri(uri: Uri): Pair<PresignedUrlData, Long> {
        val config = configManager.configFlow.first()
        if (config.apiKey.isBlank()) {
            throw IllegalStateException("API Secret Key is required. Please set it in Settings.")
        }

        val contentResolver = context.contentResolver
        val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
        val fileName = getFileNameFromUri(uri)

        val inputStream: InputStream = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Unable to open stream for URI: $uri")

        val bytes = inputStream.use { it.readBytes() }

        val presignResponse = apiService.requestPresignedUrl(
            baseUrl = config.apiBaseUrl,
            apiKey = config.apiKey,
            fileName = fileName,
            contentType = mimeType,
            contentLength = bytes.size.toLong()
        )

        val presignData = presignResponse.data

        apiService.uploadBinaryData(
            uploadUrl = presignData.uploadUrl,
            contentType = mimeType,
            data = bytes,
            headers = presignData.headers
        )

        return Pair(presignData, bytes.size.toLong())
    }

    suspend fun uploadTextSnippet(text: String): PresignedUrlData {
        val config = configManager.configFlow.first()
        if (config.apiKey.isBlank()) {
            throw IllegalStateException("API Secret Key is required. Please set it in Settings.")
        }

        val timestamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
        val fileName = "snippet-$timestamp.txt"
        val mimeType = "text/plain"
        val bytes = text.toByteArray(Charsets.UTF_8)

        val presignResponse = apiService.requestPresignedUrl(
            baseUrl = config.apiBaseUrl,
            apiKey = config.apiKey,
            fileName = fileName,
            contentType = mimeType,
            contentLength = bytes.size.toLong()
        )

        val presignData = presignResponse.data

        apiService.uploadBinaryData(
            uploadUrl = presignData.uploadUrl,
            contentType = mimeType,
            data = bytes,
            headers = presignData.headers
        )

        return presignData
    }

    private fun getFileNameFromUri(uri: Uri): String {
        var name = "file-${System.currentTimeMillis()}"
        if (uri.scheme == "content") {
            val cursor = context.contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        name = it.getString(nameIndex)
                    }
                }
            }
        } else if (uri.scheme == "file") {
            uri.lastPathSegment?.let { name = it }
        }
        return name
    }
}
