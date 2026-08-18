import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nfc_app/services/nfc_service.dart';
import 'package:nfc_app/pages/card_details_page.dart';
import 'package:nfc_app/pages/log_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String _nfcStatus = 'Checking...';
  StreamSubscription? _tagSub;

  @override
  void initState() {
    super.initState();
    _checkNfcStatus();
    _tagSub = NfcService.tagStream.listen((tagData) {
      if (_currentIndex == 0) { // Only navigate if on scan page
        NfcService.stopNfcReader();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CardDetailsPage(tagData: tagData),
          ),
        ).then((_) {
          if (_currentIndex == 0 && _nfcStatus == 'ENABLED') {
            _startReader();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tagSub?.cancel();
    NfcService.stopNfcReader();
    super.dispose();
  }

  Future<void> _checkNfcStatus() async {
    final status = await NfcService.checkNfcStatus();
    setState(() {
      _nfcStatus = status;
    });
    if (status == 'ENABLED') {
      _startReader();
    }
  }

  Future<void> _startReader() async {
    await NfcService.startNfcReader();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC Tool')),
      body: _currentIndex == 0 ? _buildScanTab() : const LogPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) {
          setState(() {
            _currentIndex = idx;
          });
          if (idx == 0 && _nfcStatus == 'ENABLED') {
            _startReader();
          } else {
            NfcService.stopNfcReader();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.nfc), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Logs'),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    if (_nfcStatus == 'NOT_SUPPORTED') {
      return const Center(child: Text('NFC is not supported on this device.'));
    }
    if (_nfcStatus == 'DISABLED') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('NFC is disabled.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await NfcService.openNfcSettings();
              },
              child: const Text('Open Settings'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkNfcStatus,
              child: const Text('Refresh'),
            )
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.nfc, size: 100, color: Colors.blue),
          SizedBox(height: 24),
          Text('Ready to Scan', style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text('Hold a MIFARE Classic card near the back of your phone.'),
        ],
      ),
    );
  }
}
