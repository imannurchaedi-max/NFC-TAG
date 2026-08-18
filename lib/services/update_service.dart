import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final uri = Uri.parse(apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link.')),
        );
      }
    }
  }
}
