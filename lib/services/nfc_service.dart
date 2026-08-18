import 'dart:async';
import 'package:flutter/services.dart';

class NfcService {
  static const MethodChannel _channel = MethodChannel('com.example.nfc_app/nfc');

  static final StreamController<Map<String, dynamic>> _tagStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get tagStream => _tagStreamController.stream;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTagDiscovered') {
        _tagStreamController.add(Map<String, dynamic>.from(call.arguments));
      }
    });
  }

  static Future<String> checkNfcStatus() async {
    return await _channel.invokeMethod('checkNfcStatus');
  }

  static Future<void> openNfcSettings() async {
    await _channel.invokeMethod('openNfcSettings');
  }

  static Future<bool> startNfcReader() async {
    return await _channel.invokeMethod('startNfcReader');
  }

  static Future<bool> stopNfcReader() async {
    return await _channel.invokeMethod('stopNfcReader');
  }

  static Future<List<Map<String, dynamic>>> readSector(int sectorIndex, String keyType, String keyHex) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('readSector', {
        'sectorIndex': sectorIndex,
        'keyType': keyType,
        'keyHex': keyHex,
      });
      return result.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> writeBlock(int blockIndex, String dataHex, String keyType, String keyHex) async {
    try {
      return await _channel.invokeMethod('writeBlock', {
        'blockIndex': blockIndex,
        'dataHex': dataHex,
        'keyType': keyType,
        'keyHex': keyHex,
      });
    } catch (e) {
      rethrow;
    }
  }
}
