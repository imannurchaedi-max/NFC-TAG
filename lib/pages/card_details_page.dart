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
  bool _nfcActive = false;

  @override
  void initState() {
    super.initState();
    // Use the initially scanned tag data (currentTag still set from scan)
    _liveTagData = widget.tagData;

    // Re-enable NFC reader so user can tap card again on Reader/Writer tab
    _startNfcListener();
  }

  void _startNfcListener() async {
    final started = await NfcService.startNfcReader();
    if (mounted) setState(() => _nfcActive = started);

    _tagSub = NfcService.tagStream.listen((tagData) {
      if (mounted) {
        setState(() {
          _liveTagData = tagData;
        });
        // Pause reader after tag detected, ready for read/write
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
            // NFC ready indicator banner
            _buildNfcBanner(),
            Expanded(
              child: TabBarView(
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
          Text(
            hasTag
                ? 'Card ready · UID: ${_liveTagData!['uid']}'
                : 'Tempel kartu NFC untuk membaca/menulis...',
            style: TextStyle(
              fontSize: 13,
              color: hasTag ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!hasTag) ...[
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
          ListTile(
            title: const Text('Size'),
            subtitle: Text('${tagData['size']} bytes'),
          ),
          ListTile(
            title: const Text('Sectors'),
            subtitle: Text('${tagData['sectorCount']}'),
          ),
          ListTile(
            title: const Text('Blocks'),
            subtitle: Text('${tagData['blockCount']}'),
          ),
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
