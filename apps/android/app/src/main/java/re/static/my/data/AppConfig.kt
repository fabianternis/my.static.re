package re.static.my.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "static_re_settings")

data class AppConfig(
    val apiKey: String = "",
    val apiBaseUrl: String = "https://my-api.static.re",
    val publicBaseUrl: String = "https://my.static.re"
)

class AppConfigManager(private val context: Context) {
    companion object {
        val KEY_API_KEY = stringPreferencesKey("api_key")
        val KEY_API_URL = stringPreferencesKey("api_base_url")
        val KEY_PUBLIC_URL = stringPreferencesKey("public_base_url")
    }

    val configFlow: Flow<AppConfig> = context.dataStore.data.map { preferences ->
        AppConfig(
            apiKey = preferences[KEY_API_KEY] ?: "",
            apiBaseUrl = preferences[KEY_API_URL] ?: "https://my-api.static.re",
            publicBaseUrl = preferences[KEY_PUBLIC_URL] ?: "https://my.static.re"
        )
    }

    suspend fun saveConfig(config: AppConfig) {
        context.dataStore.edit { preferences ->
            preferences[KEY_API_KEY] = config.apiKey.trim()
            preferences[KEY_API_URL] = config.apiBaseUrl.trim().removeSuffix("/")
            preferences[KEY_PUBLIC_URL] = config.publicBaseUrl.trim().removeSuffix("/")
        }
    }
}
