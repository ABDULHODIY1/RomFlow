package uz.romflow.offline

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import org.json.JSONObject

object LocalReminders {
    private const val CHANNEL="romflow_workshop_reminders"
    private fun prefs(c:Context)=c.getSharedPreferences("romflow_reminders",Context.MODE_PRIVATE)
    private fun intent(c:Context,id:String)=Intent(c,ReminderReceiver::class.java).apply { action="uz.romflow.offline.REMINDER";data=Uri.parse("romflow://reminder/$id");putExtra("id",id) }
    private fun pending(c:Context,id:String)=PendingIntent.getBroadcast(c,0,intent(c,id),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun allowed(c:Context):Boolean=(Build.VERSION.SDK_INT<33 || c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED) && (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
    fun schedule(c:Context,id:String,title:String,note:String,time:Long) {
        require(time>System.currentTimeMillis()) {"Eslatma vaqti o‘tgan"}
        val row=JSONObject().put("title",title).put("note",note).put("time",time)
        prefs(c).edit().putString(id,row.toString()).apply()
        (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,time,pending(c,id))
    }
    fun cancel(c:Context,id:String) {
        (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending(c,id))
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id.hashCode())
        prefs(c).edit().remove(id).apply()
    }
    fun reconcile(c:Context,items:List<Map<String,Any?>>) {
        val keep=items.mapNotNull { it["id"] as? String }.toSet()
        for(id in prefs(c).all.keys)if(id !in keep)cancel(c,id)
        if(allowed(c))for(item in items) {
          val time=(item["timeMs"] as? Number)?.toLong()?:continue
          if(time>System.currentTimeMillis())schedule(c,item["id"] as String,item["title"] as String,item["note"] as? String?:"",time)
        }
    }
    fun restore(c:Context) {
        for ((id,raw) in prefs(c).all) try {val row=JSONObject(raw as String);val time=row.getLong("time");if(time>System.currentTimeMillis())schedule(c,id,row.getString("title"),row.optString("note"),time)} catch(_:Exception) {cancel(c,id)}
    }
    fun show(c:Context,id:String) {
        val raw=prefs(c).getString(id,null)?:return
        prefs(c).edit().remove(id).apply()
        if(!allowed(c))return
        val row=JSONObject(raw)
        val manager=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if(Build.VERSION.SDK_INT>=26)manager.createNotificationChannel(NotificationChannel(CHANNEL,"Ustaxona eslatmalari",NotificationManager.IMPORTANCE_DEFAULT))
        val open=Intent(c,MainActivity::class.java).apply {flags=Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP}
        val launch=PendingIntent.getActivity(c,0,open,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=if(Build.VERSION.SDK_INT>=26)Notification.Builder(c,CHANNEL)else Notification.Builder(c)
        manager.notify(id.hashCode(),builder.setSmallIcon(android.R.drawable.ic_popup_reminder).setContentTitle(row.getString("title")).setContentText(row.optString("note")).setStyle(Notification.BigTextStyle().bigText(row.optString("note"))).setContentIntent(launch).setAutoCancel(true).build())
    }
}
class ReminderReceiver:BroadcastReceiver() {
 override fun onReceive(context:Context,intent:Intent) {
   if(intent.action==Intent.ACTION_BOOT_COMPLETED || intent.action==Intent.ACTION_MY_PACKAGE_REPLACED)LocalReminders.restore(context)
   else intent.getStringExtra("id")?.let { LocalReminders.show(context,it) }
 }
}
