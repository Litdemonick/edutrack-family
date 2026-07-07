package com.edutrack.family

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
// FlutterFragmentActivity (no FlutterActivity): requerido por local_auth (biometría)
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CH_RINGTONE = "com.edutrack/ringtone"
        private const val CH_VIBRATE  = "com.edutrack/vibrate"
        private const val CH_ALARM    = "com.edutrack/alarm"
        private const val REQ_RINGTONE = 0xFA
    }

    private var ringtoneResult: MethodChannel.Result? = null
    private var previewRingtone: Ringtone? = null
    private var alarmPlayer: MediaPlayer? = null

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

        // ── Alarm channel ────────────────────────────────────────
        // Sonido de alarma EN BUCLE (a diferencia de Ringtone.play(),
        // que suena una sola vez) — usado por el check-in "¿Estás
        // bien?": suena sin parar hasta que el estudiante responde
        // (stop) o cierra la pantalla (dispose). USAGE_ALARM: mismo
        // canal de volumen que un despertador, suena aunque el
        // celular esté en silencio/vibrar. La vibración va aparte:
        // VibrationEffect.createWaveform con repeat>=0 (en vez de -1)
        // es lo que la hace repetirse sola sin volver a llamar nada.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CH_ALARM)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loop" -> {
                        try {
                            // "sound": nombre del raw resource sin extensión —
                            // "alerta_sismica" (sismo) o "alert_sound" (check-in
                            // "¿Estás bien?", valor por defecto).
                            val soundName = call.argument<String>("sound") ?: "alert_sound"
                            val resId = resources.getIdentifier(
                                soundName, "raw", packageName)
                                .takeIf { it != 0 } ?: R.raw.alert_sound
                            alarmPlayer?.release()
                            alarmPlayer = MediaPlayer().apply {
                                val afd = resources.openRawResourceFd(resId)
                                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                                afd.close()
                                setAudioAttributes(
                                    AudioAttributes.Builder()
                                        .setUsage(AudioAttributes.USAGE_ALARM)
                                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                        .build()
                                )
                                isLooping = true
                                prepare()
                                start()
                            }
                            val pattern = longArrayOf(0, 600, 300)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val vm = getSystemService(
                                    Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                                vm.defaultVibrator.vibrate(
                                    VibrationEffect.createWaveform(pattern, 0))
                            } else {
                                @Suppress("DEPRECATION")
                                val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    v.vibrate(VibrationEffect.createWaveform(pattern, 0))
                                } else {
                                    @Suppress("DEPRECATION")
                                    v.vibrate(pattern, 0)
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ALARM_ERR", e.message, null)
                        }
                    }
                    "stop" -> {
                        alarmPlayer?.release()
                        alarmPlayer = null
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val vm = getSystemService(
                                    Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                                vm.defaultVibrator.cancel()
                            } else {
                                @Suppress("DEPRECATION")
                                val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                                v.cancel()
                            }
                        } catch (_: Exception) {}
                        result.success(null)
                    }
                    else -> result.notImplemented()
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
        alarmPlayer?.release()
        alarmPlayer = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator.cancel()
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
