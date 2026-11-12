package com.qfildroid.app.usb

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * USB Host layer built on Android UsbManager.
 *
 * Responsibilities:
 *  - enumerate USB devices and describe interfaces/endpoints,
 *  - manage USB permissions (broadcast receiver based),
 *  - open a device, claim the bulk interface and expose bulk read/write,
 *  - emit attach / detach / permission events to Flutter.
 *
 * VID/PID matching is performed in Dart (see lib/services/edl_identifier.dart);
 * this layer is protocol-agnostic and never claims a device is an EDL device.
 */
object UsbHostManager {

    private const val ACTION_USB_PERMISSION = "com.qfildroid.app.USB_PERMISSION"

    private var appContext: Context? = null
    private var usbManager: UsbManager? = null

    private val openConnections = mutableMapOf<String, UsbDeviceConnection>()
    private val claimedInterfaces = mutableMapOf<String, UsbInterface>()
    private val bulkEndpoints = mutableMapOf<String, Pair<UsbEndpoint, UsbEndpoint>>()

    var eventListener: ((Map<String, Any?>) -> Unit)? = null

    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_USB_PERMISSION) return
            val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            if (device != null) {
                emit(
                    mapOf(
                        "type" to "permission",
                        "deviceName" to device.deviceName,
                        "granted" to granted
                    )
                )
            }
        }
    }

    private val attachDetachReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    if (device != null) {
                        emit(mapOf("type" to "attached", "deviceName" to device.deviceName))
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    if (device != null) {
                        closeDevice(device.deviceName)
                        emit(mapOf("type" to "detached", "deviceName" to device.deviceName))
                    }
                }
            }
        }
    }

    fun init(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager

        val permissionFilter = IntentFilter(ACTION_USB_PERMISSION)
        val plugFilter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }

        ContextCompat.registerReceiver(
            appContext!!, permissionReceiver, permissionFilter, ContextCompat.RECEIVER_NOT_EXPORTED
        )
        ContextCompat.registerReceiver(
            appContext!!, attachDetachReceiver, plugFilter, ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    private fun emit(event: Map<String, Any?>) {
        val listener = eventListener ?: return
        ContextCompat.getMainExecutor(appContext!!).execute { listener(event) }
    }

    fun listDevices(): List<Map<String, Any?>> {
        val manager = usbManager ?: return emptyList()
        return manager.deviceList.values.map { describeDevice(it) }
    }

    fun deviceInfo(deviceName: String): Map<String, Any?>? {
        val device = findDevice(deviceName) ?: return null
        return describeDevice(device)
    }

    fun hasPermission(deviceName: String): Boolean {
        val device = findDevice(deviceName) ?: return false
        return usbManager?.hasPermission(device) ?: false
    }

    @SuppressLint("MutableCollectionMutableIntent")
    fun requestPermission(deviceName: String) {
        val manager = usbManager ?: return
        val device = findDevice(deviceName) ?: return
        if (manager.hasPermission(device)) {
            emit(mapOf("type" to "permission", "deviceName" to deviceName, "granted" to true))
            return
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        val intent = Intent(ACTION_USB_PERMISSION).setPackage(appContext!!.packageName)
        val pendingIntent = PendingIntent.getBroadcast(appContext!!, 0, intent, flags)
        manager.requestPermission(device, pendingIntent)
    }

    /**
     * Opens the device, claims the first interface that offers a bulk IN and a
     * bulk OUT endpoint (Qualcomm EDL 9008 exposes such a vendor-specific
     * interface) and stores the connection for native transport use.
     */
    fun openDevice(deviceName: String): Map<String, Any?> {
        val manager = usbManager
            ?: return mapOf("ok" to false, "error" to "USB service unavailable")
        val device = findDevice(deviceName)
            ?: return mapOf("ok" to false, "error" to "Device not found: $deviceName")
        if (!manager.hasPermission(device)) {
            return mapOf("ok" to false, "error" to "USB permission not granted")
        }
        closeDevice(deviceName)

        val selected = selectBulkInterface(device)
            ?: return mapOf(
                "ok" to false,
                "error" to "No interface with bulk IN + bulk OUT endpoints found"
            )

        val connection = manager.openDevice(device)
            ?: return mapOf("ok" to false, "error" to "openDevice returned null")
        if (!connection.claimInterface(selected.interfaceRef, true)) {
            connection.close()
            return mapOf("ok" to false, "error" to "Failed to claim interface")
        }

        openConnections[deviceName] = connection
        claimedInterfaces[deviceName] = selected.interfaceRef
        bulkEndpoints[deviceName] = Pair(selected.bulkIn, selected.bulkOut)

        return mapOf(
            "ok" to true,
            "interfaceId" to selected.interfaceRef.id,
            "bulkInEndpoint" to selected.bulkIn.endpointNumber,
            "bulkOutEndpoint" to selected.bulkOut.endpointNumber,
            "maxPacketSize" to selected.bulkIn.maxPacketSize
        )
    }

    fun closeDevice(deviceName: String) {
        bulkEndpoints.remove(deviceName)
        claimedInterfaces.remove(deviceName)?.let { iface ->
            openConnections.remove(deviceName)?.let { conn ->
                runCatching { conn.releaseInterface(iface) }
            }
        }
        openConnections.remove(deviceName)?.close()
    }

    fun closeAll() {
        for (name in openConnections.keys.toList()) closeDevice(name)
    }

    /** Called from C++ through JNI. Returns bytes written or negative on error. */
    @JvmStatic
    fun bulkWrite(deviceKey: String, data: ByteArray, timeoutMs: Int): Int {
        val connection = openConnections[deviceKey] ?: return -1
        val out = bulkEndpoints[deviceKey]?.second ?: return -2
        return connection.bulkTransfer(out, data, data.size, timeoutMs)
    }

    /** Called from C++ through JNI. Returns received bytes or null on error/timeout. */
    @JvmStatic
    fun bulkRead(deviceKey: String, maxLen: Int, timeoutMs: Int): ByteArray? {
        val connection = openConnections[deviceKey] ?: return null
        val input = bulkEndpoints[deviceKey]?.first ?: return null
        val buffer = ByteArray(maxLen)
        val read = connection.bulkTransfer(input, buffer, maxLen, timeoutMs)
        if (read < 0) return null
        return buffer.copyOf(read)
    }

    // ------------------------------------------------------------------ //

    private fun findDevice(deviceName: String): UsbDevice? {
        val manager = usbManager ?: return null
        return manager.deviceList.values.firstOrNull { it.deviceName == deviceName }
    }

    private data class SelectedInterface(
        val interfaceRef: UsbInterface,
        val bulkIn: UsbEndpoint,
        val bulkOut: UsbEndpoint
    )

    private fun selectBulkInterface(device: UsbDevice): SelectedInterface? {
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            var bulkIn: UsbEndpoint? = null
            var bulkOut: UsbEndpoint? = null
            for (e in 0 until iface.endpointCount) {
                val endpoint = iface.getEndpoint(e)
                if (endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    if (endpoint.direction == UsbConstants.USB_DIR_IN) bulkIn = endpoint
                    else if (endpoint.direction == UsbConstants.USB_DIR_OUT) bulkOut = endpoint
                }
            }
            val input = bulkIn
            val output = bulkOut
            if (input != null && output != null) {
                return SelectedInterface(iface, input, output)
            }
        }
        return null
    }

    private fun describeDevice(device: UsbDevice): Map<String, Any?> {
        val manager = usbManager
        val interfaces = ArrayList<Map<String, Any?>>()
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            val endpoints = ArrayList<Map<String, Any?>>()
            for (e in 0 until iface.endpointCount) {
                val endpoint = iface.getEndpoint(e)
                endpoints.add(
                    mapOf(
                        "endpointNumber" to endpoint.endpointNumber,
                        "direction" to if (endpoint.direction == UsbConstants.USB_DIR_IN) "in" else "out",
                        "type" to endpointTypeName(endpoint.type),
                        "maxPacketSize" to endpoint.maxPacketSize
                    )
                )
            }
            interfaces.add(
                mapOf(
                    "id" to iface.id,
                    "class" to iface.interfaceClass,
                    "subclass" to iface.interfaceSubclass,
                    "protocol" to iface.interfaceProtocol,
                    "endpoints" to endpoints
                )
            )
        }
        return mapOf(
            "deviceName" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "deviceId" to device.deviceId,
            "deviceClass" to device.deviceClass,
            "deviceSubclass" to device.deviceSubclass,
            "deviceProtocol" to device.deviceProtocol,
            "manufacturerName" to device.manufacturerName,
            "productName" to device.productName,
            "serialNumber" to device.serialNumber,
            "hasPermission" to (manager?.hasPermission(device) ?: false),
            "interfaces" to interfaces
        )
    }

    private fun endpointTypeName(type: Int): String = when (type) {
        UsbConstants.USB_ENDPOINT_XFER_CONTROL -> "control"
        UsbConstants.USB_ENDPOINT_XFER_ISOCHRONOUS -> "isochronous"
        UsbConstants.USB_ENDPOINT_XFER_BULK -> "bulk"
        UsbConstants.USB_ENDPOINT_XFER_INT -> "interrupt"
        else -> "unknown"
    }
}
