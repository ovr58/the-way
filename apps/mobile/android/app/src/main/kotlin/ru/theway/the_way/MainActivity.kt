package ru.theway.the_way

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Код страны в поле номера («Вход - Ввод номера (данные введены)»): сторона Dart — lib/src/features/auth/data/phone_country.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.theway/phone_country")
            .setMethodCallHandler { call, result ->
                if (call.method == "countryIso") result.success(phoneCountryIso()) else result.notImplemented()
            }
    }

    /** Страна SIM-карты, нет — страна сети (ISO 3166-1, строчными); null — неизвестна. Разрешений не нужно. */
    private fun phoneCountryIso(): String? = runCatching {
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        listOf(telephony?.simCountryIso, telephony?.networkCountryIso)
            .firstOrNull { !it.isNullOrBlank() }
            ?.lowercase()
    }.getOrNull()
}
