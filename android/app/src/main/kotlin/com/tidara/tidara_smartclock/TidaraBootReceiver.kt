package com.tidara.tidara_smartclock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

class TidaraBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("tidara_os_alarms", Context.MODE_PRIVATE)
        val rawJson = prefs.getString("scheduled_alarms_json", "[]") ?: "[]"
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        try {
            val array = JSONArray(rawJson)
            val nowMillis = System.currentTimeMillis()
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                val id = item.getInt("id")
                val epochMillis = item.getLong("epochMillis")
                val label = item.optString("label", "Smart Alarm")
                val audioPath = item.optString("audioPath", "")
                val timeFormatted = item.optString("timeFormatted", "")
                val soundMeta = item.optString("soundMeta", "")
                val originalAlarmId = item.optString("originalAlarmId", "")

                if (epochMillis > nowMillis) {
                    val alarmIntent = Intent(context, TidaraAlarmReceiver::class.java).apply {
                        putExtra("alarmId", id)
                        putExtra("label", label)
                        putExtra("audioPath", audioPath)
                        putExtra("timeFormatted", timeFormatted)
                        putExtra("soundMeta", soundMeta)
                        putExtra("originalAlarmId", originalAlarmId)
                    }
                    val pi = PendingIntent.getBroadcast(
                        context,
                        id,
                        alarmIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        if (alarmManager.canScheduleExactAlarms()) {
                            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                        } else {
                            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                        }
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                    } else {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                    }
                }
            }
        } catch (_: Exception) {}
    }
}