package com.qfildroid.app

import android.content.Context
import com.qfildroid.app.protocol.ProtocolBridge
import com.qfildroid.app.usb.UsbHostManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        UsbHostManager.init(this)
        UsbHostManager.eventListener = { event ->
            runOnUiThread { eventSink?.success(event) }
        }

        registerUsbChannel(flutterEngine)
        registerProtocolChannel(flutterEngine)
        registerEventChannel(flutterEngine)
    }

    override fun onDestroy() {
        UsbHostManager.closeAll()
        super.onDestroy()
    }

    private fun registerUsbChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "com.qfildroid/usb"
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "listDevices" -> result.success(UsbHostManager.listDevices())
                "deviceInfo" -> {
                    val name = call.argument<String>("deviceName")
                    result.success(UsbHostManager.deviceInfo(name ?: ""))
                }
                "hasPermission" -> {
                    val name = call.argument<String>("deviceName")
                    result.success(UsbHostManager.hasPermission(name ?: ""))
                }
                "requestPermission" -> {
                    val name = call.argument<String>("deviceName")
                    UsbHostManager.requestPermission(name ?: "")
                    result.success(true)
                }
                "openDevice" -> {
                    val name = call.argument<String>("deviceName")
                    result.success(UsbHostManager.openDevice(name ?: ""))
                }
                "closeDevice" -> {
                    val name = call.argument<String>("deviceName")
                    UsbHostManager.closeDevice(name ?: "")
                    result.success(true)
                }
                "exportLogs" -> {
                    val content = call.argument<String>("content") ?: ""
                    result.success(exportLogs(content))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun registerProtocolChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "com.qfildroid/protocol"
        )
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "engineVersion" -> result.success(ProtocolBridge.engineVersion())
                    "saharaHandshake" -> {
                        val device = call.argument<String>("deviceName") ?: ""
                        val timeout = call.argument<Int>("timeoutMs") ?: 5000
                        result.success(ProtocolBridge.saharaHandshake(device, timeout))
                    }
                    "saharaWriteImage" -> {
                        val device = call.argument<String>("deviceName") ?: ""
                        val imageId = call.argument<Int>("imageId") ?: 13
                        val data = call.argument<ByteArray>("data") ?: ByteArray(0)
                        val timeout = call.argument<Int>("timeoutMs") ?: 10000
                        result.success(
                            ProtocolBridge.saharaWriteImage(device, imageId, data, timeout)
                        )
                    }
                    "saharaDone" -> {
                        val device = call.argument<String>("deviceName") ?: ""
                        val timeout = call.argument<Int>("timeoutMs") ?: 5000
                        result.success(ProtocolBridge.saharaDone(device, timeout))
                    }
                    "saharaReset" -> {
                        val device = call.argument<String>("deviceName") ?: ""
                        val timeout = call.argument<Int>("timeoutMs") ?: 5000
                        result.success(ProtocolBridge.saharaReset(device, timeout))
                    }
                    "firehoseCommand" -> {
                        val device = call.argument<String>("deviceName") ?: ""
                        val xml = call.argument<String>("xml") ?: ""
                        val timeout = call.argument<Int>("timeoutMs") ?: 30000
                        result.success(ProtocolBridge.firehoseCommand(device, xml, timeout))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: UnsatisfiedLinkError) {
                result.error("ENGINE_MISSING", "Native engine not loaded: ${e.message}", null)
            } catch (e: Exception) {
                result.error("PROTOCOL_ERROR", e.message, null)
            }
        }
    }

    private fun registerEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.qfildroid/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    /**
     * Writes a diagnostic report to the app-specific external files directory.
     * No storage permission is required for this directory.
     */
    private fun exportLogs(content: String): Map<String, Any?> {
        return try {
            val dir = getExternalFilesDir(null) ?: filesDir
            val reportsDir = File(dir, "diagnostics")
            if (!reportsDir.exists()) reportsDir.mkdirs()
            val stamp = java.text.SimpleDateFormat(
                "yyyyMMdd_HHmmss", java.util.Locale.US
            ).format(java.util.Date())
            val file = File(reportsDir, "qfildroid_report_$stamp.log")
            file.writeText(content)
            mapOf("ok" to true, "path" to file.absolutePath)
        } catch (e: Exception) {
            mapOf("ok" to false, "error" to (e.message ?: "export failed"))
        }
    }
}
