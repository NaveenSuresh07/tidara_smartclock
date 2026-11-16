package com.tidara.tidara_smartclock

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.io.File
import kotlin.math.sin

class TidaraAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_DISMISS = "com.tidara.tidara_smartclock.ACTION_DISMISS_ALARM"
        const val ACTION_SNOOZE = "com.tidara.tidara_smartclock.ACTION_SNOOZE_ALARM"

        private var activeAlarmPlayer: MediaPlayer? = null
        private var activeWakeLock: PowerManager.WakeLock? = null
        private var activeFocusRequest: AudioFocusRequest? = null
        private var applicationContextRef: Context? = null

        fun stopRingingAudio() {
            try {
                activeAlarmPlayer?.stop()
                activeAlarmPlayer?.release()
            } catch (_: Exception) {}
            activeAlarmPlayer = null

            try {
                if (activeWakeLock?.isHeld == true) {
                    activeWakeLock?.release()
                }
            } catch (_: Exception) {}
            activeWakeLock = null

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && activeFocusRequest != null) {
                    val am = applicationContextRef?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    am?.abandonAudioFocusRequest(activeFocusRequest!!)
                }
            } catch (_: Exception) {}
            activeFocusRequest = null
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        applicationContextRef = context.applicationContext
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val alarmId = intent.getIntExtra("alarmId", 1001)
        val originalAlarmId = intent.getStringExtra("originalAlarmId") ?: alarmId.toString()
        val label = intent.getStringExtra("label") ?: "Tidara Smart Alarm"
        val audioPath = intent.getStringExtra("audioPath") ?: ""
        val timeFormatted = intent.getStringExtra("timeFormatted") ?: ""
        val soundMeta = intent.getStringExtra("soundMeta") ?: ""

        if (intent.action == ACTION_DISMISS) {
            stopRingingAudio()
            nm.cancel(alarmId)
            MainActivity.currentInstance?.onNotificationAction(ACTION_DISMISS, alarmId)
            return
        }

        if (intent.action == ACTION_SNOOZE) {
            stopRingingAudio()
            nm.cancel(alarmId)
            MainActivity.currentInstance?.onNotificationAction(ACTION_SNOOZE, alarmId)
            val snoozeTriggerMillis = System.currentTimeMillis() + 12 * 60 * 1000L
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val ringIntent = Intent(context, TidaraAlarmReceiver::class.java).apply {
                putExtra("alarmId", alarmId)
                putExtra("originalAlarmId", originalAlarmId)
                putExtra("label", label)
                putExtra("timeFormatted", timeFormatted)
                putExtra("soundMeta", soundMeta)
                putExtra("audioPath", audioPath)
            }
            val pi = PendingIntent.getBroadcast(
                context,
                alarmId,
                ringIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, snoozeTriggerMillis, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, snoozeTriggerMillis, pi)
            }
            return
        }

        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "tidara:alarm_wakelock"
        )
        wakeLock.acquire(60_000L)
        activeWakeLock = wakeLock

        startAlarmAudio(context, audioPath, label)

        val channelId = "tidara_exact_alarm_channel_v2"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Tidara Scheduled Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reliable OS-scheduled alarms and custom audio alerts"
                enableVibration(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setSound(null, null)
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.tidara.smartclock.ACTION_RING"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("alarmId", originalAlarmId)
            putExtra("numericId", alarmId)
            putExtra("title", label)
            putExtra("time", if (timeFormatted.isNotEmpty()) timeFormatted else "05:30 AM")
            putExtra("soundMeta", if (soundMeta.isNotEmpty()) soundMeta else "Soft gong | 15m gradual dawn swell")
            putExtra("audioPath", audioPath)
            putExtra("useCustomAudio", audioPath.isNotEmpty())
            putExtra("isPreview", false)
        }
        val contentPending = PendingIntent.getActivity(
            context,
            alarmId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = Intent(context, TidaraAlarmReceiver::class.java).apply {
            action = ACTION_SNOOZE
            putExtra("alarmId", alarmId)
            putExtra("originalAlarmId", originalAlarmId)
            putExtra("label", label)
            putExtra("timeFormatted", timeFormatted)
            putExtra("soundMeta", soundMeta)
            putExtra("audioPath", audioPath)
        }
        val snoozePending = PendingIntent.getBroadcast(
            context,
            alarmId + 50000,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(context, TidaraAlarmReceiver::class.java).apply {
            action = ACTION_DISMISS
            putExtra("alarmId", alarmId)
        }
        val dismissPending = PendingIntent.getBroadcast(
            context,
            alarmId + 60000,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Tidara Smart Alarm")
            .setContentText(label)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(contentPending)
            .setFullScreenIntent(contentPending, true)
            .addAction(android.R.drawable.ic_lock_idle_alarm, "Snooze 12m", snoozePending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Dismiss", dismissPending)
            .build()

        nm.notify(alarmId, notification)

        MainActivity.currentInstance?.runOnUiThread {
            val ringData = java.util.HashMap<String, Any?>().apply {
                put("alarmId", originalAlarmId)
                put("numericId", alarmId)
                put("title", label)
                put("time", if (timeFormatted.isNotEmpty()) timeFormatted else "05:30 AM")
                put("soundMeta", if (soundMeta.isNotEmpty()) soundMeta else "Soft gong | 15m gradual dawn swell")
                put("useCustomAudio", audioPath.isNotEmpty())
                put("isPreview", false)
            }
            MainActivity.currentInstance?.onRingingAlarmTriggered(ringData)
        }
    }

    private fun startAlarmAudio(context: Context, audioPath: String, label: String) {
        stopRingingAudio()
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .build()
            audioManager?.requestAudioFocus(req)
            activeFocusRequest = req
        } else {
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }

        // 1. If explicit audio file path or content URI was provided and valid, play it
        try {
            if (audioPath.isNotEmpty()) {
                if (audioPath.startsWith("content://")) {
                    activeAlarmPlayer = MediaPlayer().apply {
                        setAudioAttributes(attrs)
                        setDataSource(context, Uri.parse(audioPath))
                        isLooping = true
                        prepare()
                        start()
                    }
                    return
                } else {
                    val customFile = File(audioPath)
                    if (customFile.exists() && customFile.length() > 44L) {
                        activeAlarmPlayer = MediaPlayer().apply {
                            setAudioAttributes(attrs)
                            setDataSource(customFile.absolutePath)
                            isLooping = true
                            prepare()
                            start()
                        }
                        return
                    }
                }
            }
        } catch (_: Exception) {}

        // 2. Resolve or synthesize authentic preset audio in filesDir/preset_audio
        try {
            val presetFile = resolveOrSynthesizePresetFile(context, audioPath, label)
            if (presetFile != null && presetFile.exists() && presetFile.length() > 44L) {
                activeAlarmPlayer = MediaPlayer().apply {
                    setAudioAttributes(attrs)
                    setDataSource(presetFile.absolutePath)
                    isLooping = true
                    prepare()
                    start()
                }
                return
            }
        } catch (_: Exception) {}

        // 3. Last-ditch system ringtone fallback
        try {
            val fallbackUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            if (fallbackUri != null) {
                activeAlarmPlayer = MediaPlayer().apply {
                    setAudioAttributes(attrs)
                    setDataSource(context, fallbackUri)
                    isLooping = true
                    prepare()
                    start()
                }
            }
        } catch (_: Exception) {}
    }

    private fun resolveOrSynthesizePresetFile(context: Context, audioPath: String, label: String): File? {
        val presetDir = File(context.filesDir, "preset_audio")
        if (!presetDir.exists()) presetDir.mkdirs()

        val targetFreq: Double
        val fileName: String
        val lower = (audioPath + " " + label).lowercase()

        if (lower.contains("528") || lower.contains("solfeggio") || lower.contains("chime")) {
            targetFreq = 528.0
            fileName = "preset_528hz.wav"
        } else if (lower.contains("639") || lower.contains("dawn") || lower.contains("resonance")) {
            targetFreq = 639.0
            fileName = "preset_639hz.wav"
        } else {
            targetFreq = 432.0
            fileName = "preset_432hz.wav"
        }

        val file = File(presetDir, fileName)
        if (!file.exists() || file.length() < 100L) {
            generateSyntheticPresetWav(file, targetFreq)
        }
        return if (file.exists() && file.length() > 44L) file else null
    }

    private fun generateSyntheticPresetWav(targetFile: File, freqHz: Double, durationSec: Double = 3.5) {
        try {
            val sampleRate = 22050
            val numSamples = (sampleRate * durationSec).toInt()
            val dataSize = numSamples * 2
            val totalSize = 44 + dataSize
            val buffer = ByteArray(totalSize)

            // RIFF WAVE header
            buffer[0] = 'R'.code.toByte(); buffer[1] = 'I'.code.toByte(); buffer[2] = 'F'.code.toByte(); buffer[3] = 'F'.code.toByte()
            writeIntLE(buffer, 4, 36 + dataSize)
            buffer[8] = 'W'.code.toByte(); buffer[9] = 'A'.code.toByte(); buffer[10] = 'V'.code.toByte(); buffer[11] = 'E'.code.toByte()
            buffer[12] = 'f'.code.toByte(); buffer[13] = 'm'.code.toByte(); buffer[14] = 't'.code.toByte(); buffer[15] = ' '.code.toByte()
            writeIntLE(buffer, 16, 16)
            writeShortLE(buffer, 20, 1.toShort()) // PCM
            writeShortLE(buffer, 22, 1.toShort()) // Mono
            writeIntLE(buffer, 24, sampleRate)
            writeIntLE(buffer, 28, sampleRate * 2)
            writeShortLE(buffer, 32, 2.toShort())
            writeShortLE(buffer, 34, 16.toShort())
            buffer[36] = 'd'.code.toByte(); buffer[37] = 'a'.code.toByte(); buffer[38] = 't'.code.toByte(); buffer[39] = 'a'.code.toByte()
            writeIntLE(buffer, 40, dataSize)

            for (i in 0 until numSamples) {
                val t = i.toDouble() / sampleRate
                val env = Math.exp(-2.2 * t)
                val fundamental = sin(2.0 * Math.PI * freqHz * t)
                val overtone = 0.35 * sin(2.0 * Math.PI * freqHz * 1.5 * t)
                val sample = ((fundamental + overtone) * 0.65 * env).coerceIn(-1.0, 1.0)
                val pcm16 = (sample * 32767.0).toInt().toShort()
                writeShortLE(buffer, 44 + i * 2, pcm16)
            }

            val tmp = File("${targetFile.absolutePath}.tmp")
            tmp.writeBytes(buffer)
            tmp.renameTo(targetFile)
        } catch (_: Exception) {}
    }

    private fun writeIntLE(buffer: ByteArray, offset: Int, value: Int) {
        buffer[offset] = (value and 0xFF).toByte()
        buffer[offset + 1] = ((value shr 8) and 0xFF).toByte()
        buffer[offset + 2] = ((value shr 16) and 0xFF).toByte()
        buffer[offset + 3] = ((value shr 24) and 0xFF).toByte()
    }

    private fun writeShortLE(buffer: ByteArray, offset: Int, value: Short) {
        buffer[offset] = (value.toInt() and 0xFF).toByte()
        buffer[offset + 1] = ((value.toInt() shr 8) and 0xFF).toByte()
    }
}
