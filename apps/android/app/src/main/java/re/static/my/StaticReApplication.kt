package re.static.my

import android.app.Application
import re.static.my.data.ApiService
import re.static.my.data.AppConfigManager
import re.static.my.data.IngestionRepository

class StaticReApplication : Application() {
    lateinit var configManager: AppConfigManager
        private set
    lateinit var apiService: ApiService
        private set
    lateinit var repository: IngestionRepository
        private set

    override fun onCreate() {
        super.onCreate()
        configManager = AppConfigManager(this)
        apiService = ApiService()
        repository = IngestionRepository(this, configManager, apiService)
    }
}
