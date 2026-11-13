package com.selim.science

import android.content.Context
import android.content.pm.ApplicationInfo
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Debug
import java.io.File

/** Client-side tripwires. They raise the bar but can be bypassed (Magisk DenyList, Frida gadgets, ...);
 *  the authoritative check is Play Integrity verified on the server. */
object SecurityChecks {
    private val suPaths = listOf("/system/bin/su", "/system/xbin/su", "/sbin/su", "/system/su", "/su/bin/su",
        "/system/app/Superuser.apk", "/data/adb/magisk", "/sbin/.magisk", "/data/local/xbin/su", "/data/local/bin/su")

    fun threats(ctx: Context): List<String> {
        val t = mutableListOf<String>()
        if (isRooted()) t += "root"
        if (isEmulator()) t += "emulator"
        if ((ctx.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0 || Debug.isDebuggerConnected() || Debug.waitingForDebugger()) t += "debugger"
        if (hasHooks()) t += "hooks"
        return t
    }

    private fun isRooted(): Boolean =
        (Build.TAGS?.contains("test-keys") == true) || suPaths.any { File(it).exists() }

    private fun isEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic") || Build.FINGERPRINT.contains("emulator") || Build.FINGERPRINT.contains("vbox") ||
        Build.MODEL.contains("Emulator") || Build.MODEL.contains("Android SDK built for") || Build.MODEL.contains("sdk_gphone") ||
        Build.MANUFACTURER.contains("Genymotion") || Build.HARDWARE.contains("goldfish") || Build.HARDWARE.contains("ranchu") ||
        Build.PRODUCT.contains("sdk") || Build.PRODUCT.contains("emulator") ||
        (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))

    private fun hasHooks(): Boolean = try {
        File("/data/local/tmp/frida-server").exists() || File("/data/local/tmp/re.frida.server").exists() ||
        File("/proc/self/maps").useLines { l -> l.any { it.contains("frida", true) || it.contains("gum-js-loop") || it.contains("xposed", true) } }
    } catch (_: Throwable) { false }

    /** HDMI / Cast / mirroring creates a second display. */
    fun externalDisplay(ctx: Context): Boolean =
        (ctx.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).displays.size > 1
}
