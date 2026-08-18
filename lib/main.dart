import 'package:flutter/material.dart';
import 'package:nfc_app/services/nfc_service.dart';
import 'package:nfc_app/pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NfcService.init();
  runApp(const NfcApp());
}

class NfcApp extends StatelessWidget {
  const NfcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC RW',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
