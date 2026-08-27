package re.static.my.ui

import android.app.Application
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import re.static.my.StaticReApplication
import re.static.my.data.AppConfig
import re.static.my.data.AssetMetadata

enum class NavTab(val title: String) {
    UPLOAD("Upload"),
    ASSETS("Assets"),
    SETTINGS("Settings")
}

data class UiMessage(
    val title: String,
    val message: String,
    val isError: Boolean = false
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val app = application as StaticReApplication
    private val configManager = app.configManager
    private val apiService = app.apiService
    private val repository = app.repository

    val config: StateFlow<AppConfig> = configManager.configFlow
        .stateIn(viewModelScope, SharingStarted.Eagerly, AppConfig())

    private val _selectedTab = MutableStateFlow(NavTab.UPLOAD)
    val selectedTab = _selectedTab.asStateFlow()

    private val _isUploading = MutableStateFlow(false)
    val isUploading = _isUploading.asStateFlow()

    private val _uploadProgress = MutableStateFlow("")
    val uploadProgress = _uploadProgress.asStateFlow()

    private val _recentUploads = MutableStateFlow<List<AssetMetadata>>(emptyList())
    val recentUploads = _recentUploads.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery = _searchQuery.asStateFlow()

    private val _healthStatus = MutableStateFlow("Checking...")
    val healthStatus = _healthStatus.asStateFlow()

    private val _latencyMs = MutableStateFlow<Long?>(null)
    val latencyMs = _latencyMs.asStateFlow()

    private val _lastUploaded = MutableStateFlow<AssetMetadata?>(null)
    val lastUploaded = _lastUploaded.asStateFlow()

    private val _uiMessage = MutableStateFlow<UiMessage?>(null)
    val uiMessage = _uiMessage.asStateFlow()

    val filteredUploads: StateFlow<List<AssetMetadata>> = combine(_recentUploads, _searchQuery) { list, query ->
        if (query.isBlank()) list
        else list.filter { it.key.contains(query, ignoreCase = true) || it.contentType.contains(query, ignoreCase = true) }
    }.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())

    init {
        checkHealth()
        fetchRecentAssets()
    }

    fun selectTab(tab: NavTab) {
        _selectedTab.value = tab
    }

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun clearUiMessage() {
        _uiMessage.value = null
    }

    fun saveConfig(newConfig: AppConfig) {
        viewModelScope.launch {
            configManager.saveConfig(newConfig)
            _uiMessage.value = UiMessage("Saved", "Configuration updated successfully.")
            checkHealth()
            fetchRecentAssets()
        }
    }

    fun checkHealth() {
        viewModelScope.launch {
            val conf = config.value
            _healthStatus.value = "Checking..."
            val start = System.currentTimeMillis()
            try {
                val res = apiService.checkHealth(conf.apiBaseUrl)
                val elapsed = System.currentTimeMillis() - start
                _latencyMs.value = elapsed
                _healthStatus.value = "${res.status.uppercase()} (${elapsed}ms)"
            } catch (e: Exception) {
                _latencyMs.value = null
                _healthStatus.value = "Unreachable"
            }
        }
    }

    fun fetchRecentAssets() {
        viewModelScope.launch {
            val conf = config.value
            if (conf.apiKey.isBlank()) return@launch
            try {
                val res = apiService.listAssets(conf.apiBaseUrl, conf.apiKey, 50)
                _recentUploads.value = res.data.objects
            } catch (e: Exception) {
                // Ignore silent fetch errors
            }
        }
    }

    fun uploadUri(uri: Uri) {
        viewModelScope.launch {
            _isUploading.value = true
            _uploadProgress.value = "Uploading file..."
            try {
                val (data, size) = repository.uploadUri(uri)
                copyToClipboard(data.publicUrl, "Public Link")

                val metadata = AssetMetadata(
                    key = data.key,
                    size = size,
                    etag = "",
                    contentType = "application/octet-stream",
                    uploadedAt = data.expiresAt,
                    publicUrl = data.publicUrl
                )
                _lastUploaded.value = metadata
                _uiMessage.value = UiMessage("Upload Complete", "Public URL copied to clipboard.")
                fetchRecentAssets()
            } catch (e: Exception) {
                _uiMessage.value = UiMessage("Upload Failed", e.localizedMessage ?: "Unknown error", isError = true)
            } finally {
                _isUploading.value = false
                _uploadProgress.value = ""
            }
        }
    }

    fun pasteAndUploadFromClipboard() {
        val clipboard = getApplication<StaticReApplication>().getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip
        if (clip != null && clip.itemCount > 0) {
            val item = clip.getItemAt(0)
            val uri = item.uri
            val text = item.text?.toString()

            if (uri != null) {
                uploadUri(uri)
                return
            } else if (!text.isNullOrBlank()) {
                uploadText(text)
                return
            }
        }
        _uiMessage.value = UiMessage("Empty Clipboard", "No file, image, or text on clipboard to paste.", isError = true)
    }

    fun uploadText(text: String) {
        viewModelScope.launch {
            _isUploading.value = true
            _uploadProgress.value = "Uploading snippet..."
            try {
                val data = repository.uploadTextSnippet(text)
                copyToClipboard(data.publicUrl, "Snippet Link")

                val metadata = AssetMetadata(
                    key = data.key,
                    size = text.toByteArray().size.toLong(),
                    etag = "",
                    contentType = "text/plain",
                    uploadedAt = data.expiresAt,
                    publicUrl = data.publicUrl
                )
                _lastUploaded.value = metadata
                _uiMessage.value = UiMessage("Upload Complete", "Public URL copied to clipboard.")
                fetchRecentAssets()
            } catch (e: Exception) {
                _uiMessage.value = UiMessage("Upload Failed", e.localizedMessage ?: "Unknown error", isError = true)
            } finally {
                _isUploading.value = false
                _uploadProgress.value = ""
            }
        }
    }

    fun deleteAsset(key: String) {
        viewModelScope.launch {
            val conf = config.value
            try {
                apiService.deleteAsset(conf.apiBaseUrl, conf.apiKey, key)
                _recentUploads.value = _recentUploads.value.filter { it.key != key }
                if (_lastUploaded.value?.key == key) {
                    _lastUploaded.value = null
                }
                _uiMessage.value = UiMessage("Asset Deleted", "Removed $key from storage.")
            } catch (e: Exception) {
                _uiMessage.value = UiMessage("Delete Failed", e.localizedMessage ?: "Unknown error", isError = true)
            }
        }
    }

    fun copyToClipboard(text: String, label: String = "Link") {
        val clipboard = getApplication<StaticReApplication>().getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText(label, text)
        clipboard.setPrimaryClip(clip)
        _uiMessage.value = UiMessage("Copied to Clipboard", text)
    }
}
