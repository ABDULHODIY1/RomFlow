package uz.romflow.offline

import android.app.Activity
import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var output: ByteArray? = null
    private var reminderResult: MethodChannel.Result? = null
    private var reminderArgs: Map<String,Any?>? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger,"romflow/reminders").setMethodCallHandler { call,result ->
          try {
            if(call.method=="reconcile") {
              val items=call.argument<List<Map<String,Any?>>>("items")?:emptyList()
              LocalReminders.reconcile(this,items);result.success(null);return@setMethodCallHandler
            }
            val id=call.argument<String>("id")?:throw Exception("Eslatma ID yo‘q")
            when(call.method) {
              "cancel" -> {LocalReminders.cancel(this,id);result.success(null)}
              "schedule" -> {
                val args=call.arguments as Map<String,Any?>
                if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) {
                  if(reminderResult!=null){result.error("BUSY","Ruxsat kutilmoqda",null)}else{
                    reminderResult=result;reminderArgs=args;requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),610)
                  }
                } else { scheduleLocal(args,result) }
              }
              else -> result.notImplemented()
            }
          } catch(e:Exception){result.error("REMINDER",e.message,null)}
        }
        MethodChannel(engine.dartExecutor.binaryMessenger,"romflow/offline").setMethodCallHandler { call, result ->
            if (pending != null) { result.error("BUSY","Oldingi fayl amali tugamadi",null); return@setMethodCallHandler }
            try {
                                when(call.method) {
                    "dial" -> {
                        val phone=call.argument<String>("phone")?:""
                        startActivity(Intent(Intent.ACTION_DIAL, android.net.Uri.parse("tel:$phone")))
                        result.success(null)
                    }
                    "pickBackup" -> {
                        pending=result
                        val intent=Intent(Intent.ACTION_OPEN_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type="*/*" }
                        startActivityForResult(intent,41)
                    }
                    "saveFile" -> {
                        val raw=call.argument<Any>("bytes")
                        output=when(raw) { is ByteArray -> raw; is List<*> -> raw.map { (it as Number).toByte() }.toByteArray(); else -> throw Exception("Fayl ma’lumoti yo‘q") }
                        pending=result
                        val intent=Intent(Intent.ACTION_CREATE_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type=call.argument<String>("mime")?:"application/octet-stream"; putExtra(Intent.EXTRA_TITLE,call.argument<String>("name")?:"RomFlow-backup.json") }
                        startActivityForResult(intent,42)
                    }
                    else -> result.notImplemented()
                }
            } catch(e: Exception) { pending=null;output=null;result.error("FILE",e.message,null) }
        }
    }
    private fun scheduleLocal(args:Map<String,Any?>,result:MethodChannel.Result) {
      try {
        if(!LocalReminders.allowed(this)){result.success(false);return}
        LocalReminders.schedule(this,args["id"] as String,args["title"] as String,args["note"] as? String?:"",(args["timeMs"] as Number).toLong())
        result.success(true)
      }catch(e:Exception){result.error("REMINDER",e.message,null)}
    }
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray) {
      super.onRequestPermissionsResult(requestCode,permissions,grantResults)
      if(requestCode==610){val result=reminderResult;val args=reminderArgs;reminderResult=null;reminderArgs=null;if(result!=null){if(grantResults.firstOrNull()==PackageManager.PERMISSION_GRANTED && args!=null)scheduleLocal(args,result)else result.success(false)}}
    }
    @Deprecated("Used for Android 7+ document picker compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode!=41 && requestCode!=42)return
        val result=pending?:return;pending=null
        val bytes=output;output=null
        if(resultCode!=Activity.RESULT_OK || data?.data==null) { result.success(if(requestCode==41)null else false);return }
        try {
            val uri=data.data!!
            if(requestCode==41) {
                val raw=contentResolver.openInputStream(uri)?.use { it.readBytesLimited(10*1024*1024) }?:throw Exception("Fayl ochilmadi")
                result.success(raw.toString(Charsets.UTF_8))
            } else {
                contentResolver.openOutputStream(uri)?.use { it.write(bytes?:throw Exception("Ma’lumot yo‘q")) }?:throw Exception("Fayl yozilmadi")
                result.success(true)
            }
        } catch(e:Exception) { result.error("FILE",e.message,null) }
    }
    private fun java.io.InputStream.readBytesLimited(limit:Int):ByteArray {
        val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(8192)
        while(true){val n=read(buffer);if(n<0)break;if(out.size()+n>limit)throw Exception("Zaxira 10 MBdan katta");out.write(buffer,0,n)}
        return out.toByteArray()
    }
}
