import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nfc_app/services/nfc_service.dart';
import 'package:nfc_app/pages/reader_tab.dart';
import 'package:nfc_app/pages/writer_tab.dart';

class CardDetailsPage extends StatefulWidget {
  final Map<String, dynamic> tagData;

  const CardDetailsPage({super.key, required this.tagData});

  @override
  State<CardDetailsPage> createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends State<CardDetailsPage> {
  Map<String, dynamic>? _liveTagData;
  StreamSubscription? _tagSub;
  bool _tagReceived = false; // Debounce: ignore repeat events

  @override
  void initState() {
    super.initState();
    // Use the initially scanned data — currentTag still valid from scan
    _liveTagData = widget.tagData;
    _tagReceived = true; // We already have a tag from initial scan

    // Listen for new tag events (e.g., if user taps card again)
    _tagSub = NfcService.tagStream.listen((tagData) {
      if (!_tagReceived && mounted) {
        _tagReceived = true;
        setState(() => _liveTagData = tagData);
        // Immediately pause reader to stop repeated detection
        NfcService.pauseNfcReader();
      }
    });
  }

  @override
  void dispose() {
    _tagSub?.cancel();
    NfcService.stopNfcReader();
    super.dispose();
  }

  /// Re-enable NFC reader so user can tap card for read/write
  Future<void> _waitForCard() async {
    setState(() {
      _tagReceived = false;
      _liveTagData = null;
    });
    await NfcService.startNfcReader();
  }

  @override
  Widget build(BuildContext context) {
    final isMifareClassic = _liveTagData?['isMifareClassic'] == true;

    return DefaultTabController(
      length: isMifareClassic ? 3 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Card Details'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Info'),
              if (isMifareClassic) const Tab(text: 'Reader'),
              if (isMifareClassic) const Tab(text: 'Writer'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildNfcBanner(),
            Expanded(
              child: _liveTagData == null
                  ? _buildWaitingCard()
                  : TabBarView(
                      children: [
                        _buildInfoTab(),
                        if (isMifareClassic) ReaderTab(tagData: _liveTagData!),
                        if (isMifareClassic) WriterTab(tagData: _liveTagData!),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNfcBanner() {
    final hasTag = _liveTagData != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: hasTag ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasTag ? Icons.nfc : Icons.nfc_outlined,
            size: 18,
            color: hasTag ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasTag
                  ? 'Card ready · UID: ${_liveTagData!['uid']}'
                  : 'Menunggu kartu NFC...',
              style: TextStyle(
                fontSize: 13,
                color: hasTag ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasTag) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _waitForCard,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: Size.zero,
              ),
              child: const Text('Ganti Kartu', style: TextStyle(fontSize: 12)),
            ),
          ] else ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.nfc_outlined, size: 80, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Tempel Kartu NFC', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Dekatkan kartu MIFARE ke belakang ponsel'),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Colors.orange),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final tagData = _liveTagData ?? widget.tagData;
    final techs = (tagData['techList'] as List<dynamic>?)?.cast<String>() ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('UID (HEX)'),
          subtitle: Text(tagData['uid'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          title: const Text('Technologies'),
          subtitle: Text(techs.map((e) => e.split('.').last).join(', ')),
        ),
        if (tagData['isMifareClassic'] == true) ...[
          ListTile(title: const Text('Size'), subtitle: Text('${tagData['size']} bytes')),
          ListTile(title: const Text('Sectors'), subtitle: Text('${tagData['sectorCount']}')),
          ListTile(title: const Text('Blocks'), subtitle: Text('${tagData['blockCount']}')),
        ] else ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'This tag is not a MIFARE Classic tag. Advanced operations are not supported.',
              style: TextStyle(color: Colors.red),
            ),
          )
        ],
      ],
    );
  }
}
