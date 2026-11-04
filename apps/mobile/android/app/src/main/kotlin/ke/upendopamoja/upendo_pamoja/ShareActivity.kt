package ke.upendopamoja.upendo_pamoja

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.os.Bundle
import androidx.core.content.FileProvider
import java.io.File

/// Opened from the phone's long-press menu on the Wendo icon. It does not show an app screen.
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Thread {
            try {
                val source = File(applicationInfo.sourceDir)
                val dir = File(cacheDir, "share").apply { mkdirs() }
                val dest = File(dir, "Wendo.apk")
                source.copyTo(dest, overwrite = true)
                val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", dest)
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "application/vnd.android.package-archive"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_SUBJECT, "Wendo")
                    putExtra(
                        Intent.EXTRA_TEXT,
                        "Wendo test install. Open the file and allow installs from the app that sent it.",
                    )
                    clipData = ClipData.newRawUri("Wendo.apk", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                runOnUiThread {
                    startActivity(Intent.createChooser(send, "Share Wendo"))
                    finish()
                }
            } catch (_: Exception) {
                runOnUiThread { finish() }
            }
        }.start()
    }
}
