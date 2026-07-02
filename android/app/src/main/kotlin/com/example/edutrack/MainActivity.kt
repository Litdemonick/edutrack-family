package com.example.edutrack

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CH_RINGTONE = "com.edutrack/ringtone"
        private const val CH_VIBRATE  = "com.edutrack/vibrate"
        private const val REQ_RINGTONE = 0xFA
    }

    private var ringtoneResult: MethodChannel.Result? = null
    private var previewRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Ringtone channel ─────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CH_RINGTONE)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // Lanza el selector de tono del sistema
                    "pick" -> {
                        previewRingtone?.stop()
                        ringtoneResult = result
                        val currentUri = call.argument<String>("currentUri")
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE,
                                RingtoneManager.TYPE_NOTIFICATION)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE,
                                "Tono de notificación")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            if (currentUri != null) {
                                try {
                                    putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                                        Uri.parse(currentUri))
                                } catch (_: Exception) {}
                            }
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQ_RINGTONE)
                    }

                    // Toca una previsualización del tono
                    "play" -> {
                        previewRingtone?.stop()
                        val uriStr = call.argument<String>("uri")
                        try {
                            val uri = if (uriStr != null) Uri.parse(uriStr)
                                      else RingtoneManager.getDefaultUri(
                                               RingtoneManager.TYPE_NOTIFICATION)
                            previewRingtone = RingtoneManager.getRingtone(this, uri)
                            previewRingtone?.play()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("PLAY_ERR", e.message, null)
                        }
                    }

                    // Detiene la previsualización
                    "stop" -> {
                        previewRingtone?.stop()
                        previewRingtone = null
                        result.success(null)
                    }

                    // Devuelve el nombre de un tono dado su URI
                    "getName" -> {
                        val uriStr = call.argument<String>("uri")
                        try {
                            val uri = if (uriStr != null) Uri.parse(uriStr)
                                      else RingtoneManager.getDefaultUri(
                                               RingtoneManager.TYPE_NOTIFICATION)
                            val r = RingtoneManager.getRingtone(this, uri)
                            result.success(r?.getTitle(this) ?: "Predeterminado")
                        } catch (_: Exception) {
                            result.success("Predeterminado")
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ── Vibrate channel ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CH_VIBRATE)
            .setMethodCallHandler { call, result ->
                if (call.method == "vibrate") {
                    try {
                        val patternName = call.argument<String>("pattern") ?: "medium"
                        val pattern = when (patternName) {
                            "short" -> longArrayOf(0, 150, 100, 150)
                            "long"  -> longArrayOf(0, 600, 200, 600, 150, 600)
                            else    -> longArrayOf(0, 300, 150, 300)   // medium
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vm = getSystemService(
                                Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                            vm.defaultVibrator.vibrate(
                                VibrationEffect.createWaveform(pattern, -1))
                        } else {
                            @Suppress("DEPRECATION")
                            val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                v.vibrate(VibrationEffect.createWaveform(pattern, -1))
                            } else {
                                @Suppress("DEPRECATION")
                                v.vibrate(pattern, -1)
                            }
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("VIB_ERR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    // Resultado del selector de tono del sistema
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_RINGTONE) return

        if (resultCode == Activity.RESULT_OK && data != null) {
            @Suppress("DEPRECATION")
            val uri = data.getParcelableExtra<Uri>(
                RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            if (uri == null) {
                // Usuario eligió "Silencio"
                ringtoneResult?.success(mapOf("uri" to null, "name" to "Silencio"))
            } else {
                val name = try {
                    RingtoneManager.getRingtone(this, uri)?.getTitle(this) ?: "Personalizado"
                } catch (_: Exception) { "Personalizado" }
                ringtoneResult?.success(mapOf("uri" to uri.toString(), "name" to name))
            }
        } else {
            // Usuario canceló
            ringtoneResult?.success(null)
        }
        ringtoneResult = null
    }

    override fun onDestroy() {
        previewRingtone?.stop()
        super.onDestroy()
    }
}
