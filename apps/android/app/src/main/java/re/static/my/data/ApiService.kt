package re.static.my.data

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import java.io.InputStream

class ApiService {
    private val client = HttpClient(OkHttp) {
        install(ContentNegotiation) {
            json(Json {
                ignoreUnknownKeys = true
                isLenient = true
                encodeDefaults = true
            })
        }
        install(Logging) {
            level = LogLevel.INFO
        }
    }

    suspend fun checkHealth(baseUrl: String): HealthResponse {
        val cleanBase = baseUrl.trim().removeSuffix("/")
        return client.get("$cleanBase/health").body()
    }

    suspend fun requestPresignedUrl(
        baseUrl: String,
        apiKey: String,
        fileName: String,
        contentType: String,
        contentLength: Long? = null
    ): PresignedUrlResponse {
        val cleanBase = baseUrl.trim().removeSuffix("/")
        val req = PresignUploadRequest(
            fileName = fileName,
            contentType = contentType,
            contentLength = contentLength
        )
        return client.post("$cleanBase/upload/presign") {
            header("x-api-key", apiKey)
            contentType(ContentType.Application.Json)
            setBody(req)
        }.body()
    }

    suspend fun uploadBinaryData(
        uploadUrl: String,
        contentType: String,
        data: ByteArray,
        headers: Map<String, String>? = null
    ) {
        client.put(uploadUrl) {
            headers?.forEach { (k, v) ->
                header(k, v)
            }
            contentType(ContentType.parse(contentType))
            setBody(data)
        }
    }

    suspend fun listAssets(baseUrl: String, apiKey: String, limit: Int = 50): AssetListResponse {
        val cleanBase = baseUrl.trim().removeSuffix("/")
        return client.get("$cleanBase/assets?limit=$limit") {
            header("x-api-key", apiKey)
        }.body()
    }

    suspend fun deleteAsset(baseUrl: String, apiKey: String, key: String): AssetDeleteResponse {
        val cleanBase = baseUrl.trim().removeSuffix("/")
        return client.delete("$cleanBase/assets/$key") {
            header("x-api-key", apiKey)
        }.body()
    }
}
