package com.getgozo.user

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private var smsChannel: MethodChannel? = null
    private var smsReceiver: BroadcastReceiver? = null

    // Result of the "Allow this app to read the OTP?" popup.
    private val consentLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val message = result.data?.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)
            if (result.resultCode == RESULT_OK && message != null) {
                smsChannel?.invokeMethod("onSms", message)
            } else {
                smsChannel?.invokeMethod("onDenied", null)
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "yunido/sms_user_consent"
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startSmsListener()
                        result.success(null)
                    }
                    "stop" -> {
                        stopSmsListener()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun startSmsListener() {
        stopSmsListener()
        try {
            SmsRetriever.getClient(this).startSmsUserConsent(null)
        } catch (_: Exception) {
            return
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                val extras = intent.extras ?: return
                @Suppress("DEPRECATION")
                val status = extras.get(SmsRetriever.EXTRA_STATUS) as? Status ?: return

                when (status.statusCode) {
                    CommonStatusCodes.SUCCESS -> {
                        val consentIntent: Intent? =
                            if (Build.VERSION.SDK_INT >= 33) {
                                extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT, Intent::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT)
                            }
                        if (consentIntent != null) {
                            try {
                                consentLauncher.launch(consentIntent)
                            } catch (_: Exception) {
                                smsChannel?.invokeMethod("onDenied", null)
                            }
                        }
                    }
                    CommonStatusCodes.TIMEOUT -> smsChannel?.invokeMethod("onTimeout", null)
                }
                stopSmsListener()
            }
        }

        val filter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(receiver, filter, SmsRetriever.SEND_PERMISSION, null, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter, SmsRetriever.SEND_PERMISSION, null)
        }
        smsReceiver = receiver
    }

    private fun stopSmsListener() {
        smsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        smsReceiver = null
    }

    override fun onDestroy() {
        stopSmsListener()
        super.onDestroy()
    }
}
