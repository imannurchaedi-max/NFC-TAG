package com.example.nfc_app

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.TagLostException
import android.nfc.tech.MifareClassic
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException

class MainActivity : FlutterActivity(), NfcAdapter.ReaderCallback {

    private val CHANNEL = "com.example.nfc_app/nfc"
    private var nfcAdapter: NfcAdapter? = null
    private var currentTag: Tag? = null
    private var methodChannel: MethodChannel? = null
    private val scope = CoroutineScope(Dispatchers.IO + Job())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNfcStatus" -> {
                    if (nfcAdapter == null) {
                        result.success("NOT_SUPPORTED")
                    } else if (!nfcAdapter!!.isEnabled) {
                        result.success("DISABLED")
                    } else {
                        result.success("ENABLED")
                    }
                }
                "openNfcSettings" -> {
                    startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                    result.success(null)
                }
                "startNfcReader" -> {
                    if (nfcAdapter != null && nfcAdapter!!.isEnabled) {
                        val flags = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V
                        nfcAdapter!!.enableReaderMode(this, this, flags, null)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stopNfcReader" -> {
                    nfcAdapter?.disableReaderMode(this)
                    currentTag = null
                    result.success(true)
                }
                "readSector" -> {
                    val sectorIndex = call.argument<Int>("sectorIndex") ?: 0
                    val keyType = call.argument<String>("keyType") ?: "A"
                    val keyHex = call.argument<String>("keyHex") ?: ""
                    readSector(sectorIndex, keyType, keyHex, result)
                }
                "writeBlock" -> {
                    val blockIndex = call.argument<Int>("blockIndex") ?: 0
                    val dataHex = call.argument<String>("dataHex") ?: ""
                    val keyType = call.argument<String>("keyType") ?: "A"
                    val keyHex = call.argument<String>("keyHex") ?: ""
                    writeBlock(blockIndex, dataHex, keyType, keyHex, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onTagDiscovered(tag: Tag?) {
        if (tag == null) return
        currentTag = tag

        val uid = tag.id.joinToString(":") { String.format("%02X", it) }
        val techs = tag.techList.toList()
        val isMifareClassic = techs.contains(MifareClassic::class.java.name)

        val metadata = mutableMapOf<String, Any>(
            "uid" to uid,
            "techList" to techs,
            "isMifareClassic" to isMifareClassic
        )

        if (isMifareClassic) {
            val mfc = MifareClassic.get(tag)
            if (mfc != null) {
                metadata["size"] = mfc.size
                metadata["sectorCount"] = mfc.sectorCount
                metadata["blockCount"] = mfc.blockCount
            }
        }

        runOnUiThread {
            methodChannel?.invokeMethod("onTagDiscovered", metadata)
        }
    }

    private fun readSector(sectorIndex: Int, keyType: String, keyHex: String, result: MethodChannel.Result) {
        if (currentTag == null) {
            result.error("NO_TAG", "No NFC tag currently detected.", null)
            return
        }

        val mfc = MifareClassic.get(currentTag)
        if (mfc == null) {
            result.error("NOT_SUPPORTED", "Tag is not MIFARE Classic.", null)
            return
        }

        val key = hexStringToByteArray(keyHex)
        if (key.size != 6) {
            result.error("INVALID_KEY", "Key must be exactly 6 bytes.", null)
            return
        }

        scope.launch {
            try {
                mfc.connect()
                val authSuccess = if (keyType == "A") {
                    mfc.authenticateSectorWithKeyA(sectorIndex, key)
                } else {
                    mfc.authenticateSectorWithKeyB(sectorIndex, key)
                }

                if (!authSuccess) {
                    withContext(Dispatchers.Main) {
                        result.error("AUTH_FAILED", "Authentication failed for sector \$sectorIndex.", null)
                    }
                    return@launch
                }

                val blocks = mutableListOf<Map<String, String>>()
                val firstBlock = mfc.sectorToBlock(sectorIndex)
                val blockCount = mfc.getBlockCountInSector(sectorIndex)

                for (i in 0 until blockCount) {
                    val blockIndex = firstBlock + i
                    val data = mfc.readBlock(blockIndex)
                    
                    var hexData = byteArrayToHexString(data)
                    var asciiData = byteArrayToSafeAscii(data)
                    
                    if (i == blockCount - 1) {
                        hexData = "XXXXXXXXXXXX" + hexData.substring(12)
                        asciiData = "......" + asciiData.substring(6)
                    }
                    
                    blocks.add(mapOf(
                        "blockIndex" to blockIndex.toString(),
                        "hex" to hexData,
                        "ascii" to asciiData
                    ))
                }
                
                withContext(Dispatchers.Main) {
                    result.success(blocks)
                }
            } catch (e: TagLostException) {
                withContext(Dispatchers.Main) { result.error("TAG_LOST", "Tag connection lost.", null) }
            } catch (e: IOException) {
                withContext(Dispatchers.Main) { result.error("IO_ERROR", e.message, null) }
            } catch (e: SecurityException) {
                withContext(Dispatchers.Main) { result.error("SECURITY_ERROR", e.message, null) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { result.error("UNKNOWN_ERROR", e.message, null) }
            } finally {
                try { mfc.close() } catch (e: Exception) {}
            }
        }
    }

    private fun writeBlock(blockIndex: Int, dataHex: String, keyType: String, keyHex: String, result: MethodChannel.Result) {
        if (currentTag == null) {
            result.error("NO_TAG", "No NFC tag currently detected.", null)
            return
        }

        val mfc = MifareClassic.get(currentTag)
        if (mfc == null) {
            result.error("NOT_SUPPORTED", "Tag is not MIFARE Classic.", null)
            return
        }

        if (blockIndex == 0) {
            result.error("INVALID_BLOCK", "Writing to manufacturer block 0 is rejected.", null)
            return
        }

        val sectorIndex = mfc.blockToSector(blockIndex)
        val firstBlock = mfc.sectorToBlock(sectorIndex)
        val blockCount = mfc.getBlockCountInSector(sectorIndex)
        val trailerBlock = firstBlock + blockCount - 1
        
        if (blockIndex == trailerBlock) {
             result.error("INVALID_BLOCK", "Writing to sector trailer is rejected by default.", null)
             return
        }

        val key = hexStringToByteArray(keyHex)
        if (key.size != 6) {
            result.error("INVALID_KEY", "Key must be exactly 6 bytes.", null)
            return
        }

        val data = hexStringToByteArray(dataHex)
        if (data.size != 16) {
            result.error("INVALID_DATA", "Payload must be exactly 16 bytes.", null)
            return
        }

        scope.launch {
            try {
                mfc.connect()
                val authSuccess = if (keyType == "A") {
                    mfc.authenticateSectorWithKeyA(sectorIndex, key)
                } else {
                    mfc.authenticateSectorWithKeyB(sectorIndex, key)
                }

                if (!authSuccess) {
                    withContext(Dispatchers.Main) { result.error("AUTH_FAILED", "Authentication failed for sector \$sectorIndex.", null) }
                    return@launch
                }

                mfc.writeBlock(blockIndex, data)
                
                val readBackData = mfc.readBlock(blockIndex)
                if (!data.contentEquals(readBackData)) {
                    withContext(Dispatchers.Main) { result.error("VERIFICATION_FAILED", "Data written does not match read-back data.", null) }
                    return@launch
                }

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: TagLostException) {
                withContext(Dispatchers.Main) { result.error("TAG_LOST", "Tag connection lost.", null) }
            } catch (e: IOException) {
                withContext(Dispatchers.Main) { result.error("IO_ERROR", e.message, null) }
            } catch (e: SecurityException) {
                withContext(Dispatchers.Main) { result.error("SECURITY_ERROR", e.message, null) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { result.error("UNKNOWN_ERROR", e.message, null) }
            } finally {
                try { mfc.close() } catch (e: Exception) {}
            }
        }
    }

    private fun hexStringToByteArray(s: String): ByteArray {
        val len = s.length
        val data = ByteArray(len / 2)
        var i = 0
        while (i < len) {
            data[i / 2] = ((Character.digit(s[i], 16) shl 4) + Character.digit(s[i + 1], 16)).toByte()
            i += 2
        }
        return data
    }

    private fun byteArrayToHexString(bytes: ByteArray): String {
        val hexChars = CharArray(bytes.size * 2)
        for (j in bytes.indices) {
            val v = bytes[j].toInt() and 0xFF
            hexChars[j * 2] = "0123456789ABCDEF"[v ushr 4]
            hexChars[j * 2 + 1] = "0123456789ABCDEF"[v and 0x0F]
        }
        return String(hexChars)
    }

    private fun byteArrayToSafeAscii(bytes: ByteArray): String {
        val sb = StringBuilder()
        for (b in bytes) {
            val v = b.toInt() and 0xFF
            if (v in 32..126) {
                sb.append(v.toChar())
            } else {
                sb.append('.')
            }
        }
        return sb.toString()
    }
}
