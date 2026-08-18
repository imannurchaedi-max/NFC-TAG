import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class UpdateService {
  static const String versionUrl = 'https://raw.githubusercontent.com/imannurchaedi-max/NFC-TAG/main/release/version.json';
  static const MethodChannel _channel = MethodChannel('com.example.nfc_app/nfc');

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final remoteVersion = data['version'];
        final apkUrl = data['apk_url'];

        if (_isNewerVersion(currentVersion, remoteVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, remoteVersion, apkUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static bool _isNewerVersion(String current, String remote) {
    final v1 = current.split('.').map(int.parse).toList();
    final v2 = remote.split('.').map(int.parse).toList();

    for (var i = 0; i < v1.length; i++) {
      if (i >= v2.length) return false;
      if (v2[i] > v1[i]) return true;
      if (v2[i] < v1[i]) return false;
    }
    return v2.length > v1.length;
  }

  static void _showUpdateDialog(BuildContext context, String newVersion, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available!'),
        content: Text('A new version of NFC RW (v$newVersion) is available. Would you like to update now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('LATER')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(context, apkUrl);
            },
            child: const Text('UPDATE NOW'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(BuildContext context, String apkUrl) async {
    final progressNotifier = ValueNotifier<double>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Downloading Update...'),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, value, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 8),
                Text('${(value * 100).toStringAsFixed(0)}%'),
              ],
            );
          },
        ),
      ),
    );

    try {
      final dir = await getExternalStorageDirectory(); // Android only
      final filePath = '${dir?.path}/update.apk';

      final dio = Dio();
      await dio.download(
        apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progressNotifier.value = received / total;
          }
        },
      );

      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
      }

      // Trigger native installation
      await _channel.invokeMethod('installApk', {'filePath': filePath});

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }
}
