package re.static.my.data

import kotlinx.serialization.Serializable

@Serializable
data class HealthResponse(
    val status: String,
    val timestamp: String,
    val version: String,
    val environment: String,
    val services: ServiceStatus
)

@Serializable
data class ServiceStatus(
    val r2Bucket: String
)

@Serializable
data class PresignUploadRequest(
    val fileName: String,
    val contentType: String,
    val key: String? = null,
    val contentLength: Long? = null,
    val customMetadata: Map<String, String>? = null,
    val expiresInSeconds: Int? = null
)

@Serializable
data class PresignedUrlResponse(
    val success: Boolean,
    val data: PresignedUrlData
)

@Serializable
data class PresignedUrlData(
    val key: String,
    val uploadUrl: String,
    val method: String,
    val headers: Map<String, String>,
    val publicUrl: String,
    val expiresAt: String,
    val expiresInSeconds: Int
)

@Serializable
data class DirectUploadResponse(
    val success: Boolean,
    val data: DirectUploadData
)

@Serializable
data class DirectUploadData(
    val key: String,
    val size: Long,
    val contentType: String,
    val publicUrl: String
)

@Serializable
data class AssetMetadata(
    val key: String,
    val size: Long,
    val etag: String,
    val contentType: String,
    val uploadedAt: String,
    val publicUrl: String,
    val customMetadata: Map<String, String>? = null
)

@Serializable
data class AssetListResponse(
    val success: Boolean,
    val data: AssetListData
)

@Serializable
data class AssetListData(
    val objects: List<AssetMetadata>,
    val truncated: Boolean,
    val cursor: String? = null
)

@Serializable
data class AssetDeleteResponse(
    val success: Boolean,
    val data: AssetDeleteData
)

@Serializable
data class AssetDeleteData(
    val key: String,
    val deleted: Boolean
)
