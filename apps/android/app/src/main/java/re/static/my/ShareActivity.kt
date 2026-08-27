package re.static.my

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import re.static.my.ui.theme.MyStaticReTheme

class ShareActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val app = application as StaticReApplication
        val repository = app.repository

        setContent {
            MyStaticReTheme {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surface,
                    modifier = Modifier.padding(24.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                            Text("Uploading to StaticRe...", style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }
        }

        handleIncomingIntent(repository)
    }

    private fun handleIncomingIntent(repository: re.static.my.data.IngestionRepository) {
        val intent = intent
        val action = intent.action
        val type = intent.type

        lifecycleScope.launch {
            try {
                if (Intent.ACTION_SEND == action && type != null) {
                    if (intent.hasExtra(Intent.EXTRA_STREAM)) {
                        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                        if (uri != null) {
                            val (data, _) = repository.uploadUri(uri)
                            copyAndNotify(data.publicUrl)
                        }
                    } else if (intent.hasExtra(Intent.EXTRA_TEXT)) {
                        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                        if (!text.isNullOrBlank()) {
                            val data = repository.uploadTextSnippet(text)
                            copyAndNotify(data.publicUrl)
                        }
                    }
                } else if (Intent.ACTION_SEND_MULTIPLE == action && type != null) {
                    val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                    if (!uris.isNullOrEmpty()) {
                        val urls = mutableListOf<String>()
                        for (uri in uris) {
                            val (data, _) = repository.uploadUri(uri)
                            urls.add(data.publicUrl)
                        }
                        copyAndNotify(urls.joinToString("\n"))
                    }
                }
            } catch (e: Exception) {
                Toast.makeText(this@ShareActivity, "Upload failed: ${e.localizedMessage}", Toast.LENGTH_LONG).show()
            } finally {
                finish()
            }
        }
    }

    private fun copyAndNotify(url: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("StaticRe URL", url)
        clipboard.setPrimaryClip(clip)
        Toast.makeText(this, "Uploaded! Link copied to clipboard", Toast.LENGTH_SHORT).show()
    }
}
