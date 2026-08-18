import 'package:flutter/material.dart';
import 'package:nfc_app/pages/reader_tab.dart';
import 'package:nfc_app/pages/writer_tab.dart';

class CardDetailsPage extends StatelessWidget {
  final Map<String, dynamic> tagData;

  const CardDetailsPage({super.key, required this.tagData});

  @override
  Widget build(BuildContext context) {
    final isMifareClassic = tagData['isMifareClassic'] == true;

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
        body: TabBarView(
          children: [
            _buildInfoTab(),
            if (isMifareClassic) ReaderTab(tagData: tagData),
            if (isMifareClassic) WriterTab(tagData: tagData),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
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
