package com.tidara.tidara_smartclock

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.ArrayList
import java.util.HashMap

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.tidara.smartclock/native_bridge"
        @Volatile
        var currentInstance: MainActivity? = null
    }

    private val PICK_AUDIO_REQUEST_CODE = 4091

    private var mediaPlayer: MediaPlayer? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var pendingAudioPickResult: MethodChannel.Result? = null
    private var initialRingingAlarm: HashMap<String, Any?>? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentInstance = this
        configureWindowForLockscreen()
        handleRingingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        configureWindowForLockscreen()
        handleRingingIntent(intent)
    }

    private fun configureWindowForLockscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    fun keepScreenOnWhileRinging(enable: Boolean) {
        runOnUiThread {
            if (enable) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    private fun extractAlarmData(intent: Intent?): HashMap<String, Any?>? {
        if (intent == null) return null
        val action = intent.action
        val isRingAction = action == "com.tidara.smartclock.ACTION_RING"
        val alarmId = intent.getStringExtra("alarmId")
            ?: intent.getIntExtra("triggeredAlarmId", -1).let { if (it != -1) it.toString() else null }
        if (alarmId == null && !isRingAction) return null

        val map = HashMap<String, Any?>()
        map["alarmId"] = alarmId ?: "alarm-os"
        map["numericId"] = intent.getIntExtra("numericId", 1001)
        map["title"] = intent.getStringExtra("title") ?: intent.getStringExtra("label") ?: "Solar Awakening"
        map["time"] = intent.getStringExtra("time") ?: "05:30 AM"
        map["soundMeta"] = intent.getStringExtra("soundMeta") ?: "Soft gong | 15m gradual dawn swell"
        map["useCustomAudio"] = intent.getBooleanExtra("useCustomAudio", false)
        map["isPreview"] = false
        return map
    }

    fun onRingingAlarmTriggered(alarmData: HashMap<String, Any?>) {
        initialRingingAlarm = alarmData
        keepScreenOnWhileRinging(true)
        methodChannel?.invokeMethod("onRingingAlarmTriggered", alarmData)
    }

    private fun handleRingingIntent(intent: Intent?) {
        val alarmData = extractAlarmData(intent) ?: return
        onRingingAlarmTriggered(alarmData)
    }

    fun onNotificationAction(action: String, alarmId: Int) {
        runOnUiThread {
            keepScreenOnWhileRinging(false)
            val map = HashMap<String, Any>()
            map["action"] = if (action == TidaraAlarmReceiver.ACTION_SNOOZE) "snooze" else "dismiss"
            map["alarmId"] = alarmId
            methodChannel?.invokeMethod("onNotificationAction", map)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRingingAlarm" -> {
                    val alarm = initialRingingAlarm
                    initialRingingAlarm = null
                    result.success(alarm)
                }
                "clearKeepScreenOn" -> {
                    keepScreenOnWhileRinging(false)
                    result.success(true)
                }
                "getAlarmPermissionStatus" -> {
                    val status = HashMap<String, Any>()
                    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true
                    status["canScheduleExact"] = canExact

                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val notificationsEnabled = if (Build.VERSION.SDK_INT >= 33) {
                        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED && nm.areNotificationsEnabled()
                    } else {
                        nm.areNotificationsEnabled()
                    }
                    status["notificationsEnabled"] = notificationsEnabled

                    var channelValid = true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val ch = nm.getNotificationChannel("tidara_exact_alarm_channel_v2")
                        if (ch != null && ch.importance < NotificationManager.IMPORTANCE_HIGH) {
                            channelValid = false
                        }
                    }
                    status["alarmChannelValid"] = channelValid

                    val canFullScreen = if (Build.VERSION.SDK_INT >= 34) {
                        nm.canUseFullScreenIntent()
                    } else true
                    status["canUseFullScreenIntent"] = canFullScreen

                    result.success(status)
                }
                "openNotificationSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "openAlarmChannelSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                putExtra(Settings.EXTRA_CHANNEL_ID, "tidara_exact_alarm_channel_v2")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "openFullScreenIntentSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= 34) {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (_: Exception) {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                }
                "getDurableStorageDir" -> {
                    result.success(applicationContext.filesDir.absolutePath)
                }
                "pickAudioFileFromDevice" -> {
                    if (pendingAudioPickResult != null) {
                        result.error("BUSY", "An audio picker request is already active.", null)
                        return@setMethodCallHandler
                    }
                    pendingAudioPickResult = result
                    launchSystemAudioDocumentPicker()
                }
                "listDeviceAudio" -> {
                    result.success(queryAllAccessibleAudioFiles())
                }
                "playAudioFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    val loop = call.argument<Boolean>("loop") ?: false
                    result.success(playLocalAudioWithFocus(path, loop))
                }
                "playWavBytes" -> {
                    val bytes = call.argument<ByteArray>("wavBytes")
                    val loop = call.argument<Boolean>("loop") ?: false
                    if (bytes != null && bytes.isNotEmpty()) {
                        val audioDir = File(applicationContext.filesDir, "custom_alarm_audio")
                        if (!audioDir.exists()) audioDir.mkdirs()
                        val wavFile = File(audioDir, "tidara_synth_preview.wav")
                        wavFile.writeBytes(bytes)
                        result.success(playLocalAudioWithFocus(wavFile.absolutePath, loop))
                    } else {
                        result.success(false)
                    }
                }
                "stopAudio" -> {
                    stopLocalAudio()
                    TidaraAlarmReceiver.stopRingingAudio()
                    keepScreenOnWhileRinging(false)
                    result.success(true)
                }
                "requestAlarmAndNotificationPermissions" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        if (!granted) {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4092)
                        }
                    }
                    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val exactAllowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true
                    result.success(exactAllowed)
                }
                "canScheduleExactAlarms" -> {
                    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        am.canScheduleExactAlarms()
                    } else true
                    result.success(allowed)
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "scheduleExactAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1001
                    val epochMillis = call.argument<Number>("epochMillis")?.toLong() ?: 0L
                    val label = call.argument<String>("label") ?: "Smart Alarm"
                    val audioPath = call.argument<String>("audioPath") ?: ""
                    val timeFormatted = call.argument<String>("timeFormatted") ?: ""
                    val soundMeta = call.argument<String>("soundMeta") ?: ""
                    val originalAlarmId = call.argument<String>("originalAlarmId") ?: ""
                    result.success(scheduleNativeExactAlarm(id, epochMillis, label, audioPath, timeFormatted, soundMeta, originalAlarmId))
                }
                "cancelExactAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1001
                    cancelNativeExactAlarm(id)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchSystemAudioDocumentPicker() {
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "audio/*"
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf(
                        "audio/mpeg",
                        "audio/mp3",
                        "audio/wav",
                        "audio/x-wav",
                        "audio/mp4",
                        "audio/x-m4a",
                        "audio/aac",
                        "audio/ogg",
                        "audio/flac"
                    )
                )
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
            startActivityForResult(intent, PICK_AUDIO_REQUEST_CODE)
        } catch (e: Exception) {
            pendingAudioPickResult?.success(null)
            pendingAudioPickResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_AUDIO_REQUEST_CODE) {
            val callback = pendingAudioPickResult
            pendingAudioPickResult = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback?.success(null)
                return
            }
            val uri = data.data!!
            val copiedItem = importSelectedAudioUriToDurableStorage(uri)
            callback?.success(copiedItem)
        }
    }

    private fun importSelectedAudioUriToDurableStorage(uri: Uri): HashMap<String, String>? {
        return try {
            val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            try {
                contentResolver.takePersistableUriPermission(uri, takeFlags)
            } catch (_: Exception) {}

            var displayName = "Custom_Audio.mp3"
            var fileSize = -1L
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIdx >= 0) {
                        val rawName = cursor.getString(nameIdx)
                        if (!rawName.isNullOrBlank()) displayName = rawName
                    }
                    if (sizeIdx >= 0 && !cursor.isNull(sizeIdx)) {
                        fileSize = cursor.getLong(sizeIdx)
                    }
                }
            }

            // Reject empty or > 80MB files safely
            if (fileSize == 0L || fileSize > 80L * 1024L * 1024L) {
                return null
            }

            val lower = displayName.lowercase()
            val hasValidExt = lower.endsWith(".mp3") ||
                lower.endsWith(".wav") ||
                lower.endsWith(".m4a") ||
                lower.endsWith(".aac") ||
                lower.endsWith(".ogg") ||
                lower.endsWith(".flac")
            if (!hasValidExt) {
                displayName = "$displayName.mp3"
            }

            val audioDir = File(applicationContext.filesDir, "custom_alarm_audio")
            if (!audioDir.exists()) audioDir.mkdirs()

            val safeFileName = displayName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val targetFile = File(audioDir, safeFileName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(targetFile).use { output ->
                    val buffer = ByteArray(16 * 1024)
                    var read: Int
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            }

            if (!targetFile.exists() || targetFile.length() <= 0L) {
                return null
            }

            // Verify MediaPlayer can decode the imported file before accepting it
            val probe = MediaPlayer()
            try {
                probe.setDataSource(targetFile.absolutePath)
                probe.prepare()
            } catch (e: Exception) {
                targetFile.delete()
                return null
            } finally {
                try { probe.release() } catch (_: Exception) {}
            }

            val result = HashMap<String, String>()
            result["name"] = displayName
            result["path"] = targetFile.absolutePath
            result["uri"] = uri.toString()
            result
        } catch (_: Exception) {
            null
        }
    }

    private fun queryAllAccessibleAudioFiles(): ArrayList<HashMap<String, String>> {
        val list = ArrayList<HashMap<String, String>>()
        // 1. Always include previously imported custom audio files in filesDir/custom_alarm_audio
        try {
            val audioDir = File(applicationContext.filesDir, "custom_alarm_audio")
            if (audioDir.exists()) {
                audioDir.listFiles()?.forEach { file ->
                    if (file.isFile && file.length() > 0 && file.name != "tidara_synth_preview.wav") {
                        val map = HashMap<String, String>()
                        map["name"] = file.name
                        map["path"] = file.absolutePath
                        list.add(map)
                    }
                }
            }
        } catch (_: Exception) {}

        // 2. Also query MediaStore if permission is already granted
        try {
            val projection = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DISPLAY_NAME
            )
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                "${MediaStore.Audio.Media.DISPLAY_NAME} ASC"
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                var count = 0
                while (cursor.moveToNext() && count < 30) {
                    val id = cursor.getLong(idCol)
                    val name = cursor.getString(nameCol) ?: "Audio Track"
                    val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                    val map = HashMap<String, String>()
                    map["name"] = name
                    map["path"] = contentUri.toString()
                    map["uri"] = contentUri.toString()
                    list.add(map)
                    count++
                }
            }
        } catch (_: Exception) {}
        return list
    }

    private fun scheduleNativeExactAlarm(
        id: Int,
        epochMillis: Long,
        label: String,
        audioPath: String,
        timeFormatted: String = "",
        soundMeta: String = "",
        originalAlarmId: String = ""
    ): Boolean {
        return try {
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(applicationContext, TidaraAlarmReceiver::class.java).apply {
                putExtra("alarmId", id)
                putExtra("label", label)
                putExtra("audioPath", audioPath)
                putExtra("timeFormatted", timeFormatted)
                putExtra("soundMeta", soundMeta)
                putExtra("originalAlarmId", originalAlarmId)
            }
            val pi = PendingIntent.getBroadcast(
                applicationContext,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pi)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, epochMillis, pi)
            }
            persistAlarmRecord(id, epochMillis, label, audioPath, timeFormatted, soundMeta, originalAlarmId)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun cancelNativeExactAlarm(id: Int) {
        try {
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(applicationContext, TidaraAlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                applicationContext,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pi)
            removePersistedAlarmRecord(id)
        } catch (_: Exception) {}
    }

    private fun persistAlarmRecord(
        id: Int,
        epochMillis: Long,
        label: String,
        audioPath: String,
        timeFormatted: String = "",
        soundMeta: String = "",
        originalAlarmId: String = ""
    ) {
        val prefs = getSharedPreferences("tidara_os_alarms", Context.MODE_PRIVATE)
        val raw = prefs.getString("scheduled_alarms_json", "[]") ?: "[]"
        val arr = JSONArray(raw)
        val updated = JSONArray()
        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (obj.optInt("id") != id) updated.put(obj)
        }
        val entry = JSONObject().apply {
            put("id", id)
            put("epochMillis", epochMillis)
            put("label", label)
            put("audioPath", audioPath)
            put("timeFormatted", timeFormatted)
            put("soundMeta", soundMeta)
            put("originalAlarmId", originalAlarmId)
        }
        updated.put(entry)
        prefs.edit().putString("scheduled_alarms_json", updated.toString()).apply()
    }

    private fun removePersistedAlarmRecord(id: Int) {
        val prefs = getSharedPreferences("tidara_os_alarms", Context.MODE_PRIVATE)
        val raw = prefs.getString("scheduled_alarms_json", "[]") ?: "[]"
        val arr = JSONArray(raw)
        val updated = JSONArray()
        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (obj.optInt("id") != id) updated.put(obj)
        }
        prefs.edit().putString("scheduled_alarms_json", updated.toString()).apply()
    }

    private fun playLocalAudioWithFocus(path: String, loop: Boolean): Boolean {
        return try {
            stopLocalAudio()
            if (path.isEmpty()) return false

            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(attrs)
                    .setOnAudioFocusChangeListener { change ->
                        if (change == AudioManager.AUDIOFOCUS_LOSS) stopLocalAudio()
                    }
                    .build()
                audioFocusRequest = req
                audioManager.requestAudioFocus(req)
            }

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(attrs)
                if (path.startsWith("content://")) {
                    setDataSource(applicationContext, Uri.parse(path))
                } else {
                    val file = File(path)
                    if (!file.exists() || file.length() <= 0L) return false
                    setDataSource(file.absolutePath)
                }
                isLooping = loop
                prepare()
                start()
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun stopLocalAudio() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { req ->
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.abandonAudioFocusRequest(req)
            }
        }
    }




    override fun onDestroy() {
        if (currentInstance == this) {
            currentInstance = null
        }
        stopLocalAudio()
        super.onDestroy()
    }
}