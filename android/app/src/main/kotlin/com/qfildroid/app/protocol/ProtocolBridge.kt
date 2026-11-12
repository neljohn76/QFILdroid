package com.qfildroid.app.protocol

import com.qfildroid.app.usb.UsbHostManager

/**
 * Bridge to the C++ protocol engine (libs qfildroid_engine).
 *
 * The native engine owns Sahara/Firehose protocol framing and state. Bulk
 * endpoint transfers are delegated back to [NativeUsbBridge], which forwards
 * to [UsbHostManager]. The engine is never given direct file descriptors.
 */
object ProtocolBridge {

    init {
        System.loadLibrary("qfildroid_engine")
    }

    @JvmStatic
    external fun engineVersion(): String

    /** Performs the Sahara handshake. Returns {ok, version, mode, error}. */
    @JvmStatic
    external fun saharaHandshake(deviceKey: String, timeoutMs: Int): HashMap<String, Any?>

    /**
     * Transfers a programmer (firehose loader) image over Sahara.
     * Returns {ok, imageId, bytesSent, status, error}.
     */
    @JvmStatic
    external fun saharaWriteImage(
        deviceKey: String,
        imageId: Int,
        data: ByteArray,
        timeoutMs: Int
    ): HashMap<String, Any?>

    /** Sends SAHARA_DONE and reads the response. */
    @JvmStatic
    external fun saharaDone(deviceKey: String, timeoutMs: Int): HashMap<String, Any?>

    /** Sends SAHARA_RESET and reads the response. */
    @JvmStatic
    external fun saharaReset(deviceKey: String, timeoutMs: Int): HashMap<String, Any?>

    /** Sends a raw Firehose XML command and returns {ok, response, logs, error}. */
    @JvmStatic
    external fun firehoseCommand(deviceKey: String, xml: String, timeoutMs: Int): HashMap<String, Any?>
}

/** JNI entry points for the C++ engine's bulk transport callbacks. */
object NativeUsbBridge {
    @JvmStatic
    fun bulkWrite(deviceKey: String, data: ByteArray, timeoutMs: Int): Int =
        UsbHostManager.bulkWrite(deviceKey, data, timeoutMs)

    @JvmStatic
    fun bulkRead(deviceKey: String, maxLen: Int, timeoutMs: Int): ByteArray? =
        UsbHostManager.bulkRead(deviceKey, maxLen, timeoutMs)
}
