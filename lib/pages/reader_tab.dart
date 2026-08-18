import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_app/services/nfc_service.dart';
import 'package:nfc_app/services/log_service.dart';

class ReaderTab extends StatefulWidget {
  final Map<String, dynamic> tagData;
  const ReaderTab({super.key, required this.tagData});

  @override
  State<ReaderTab> createState() => _ReaderTabState();
}

class _ReaderTabState extends State<ReaderTab> {
  final _sectorController = TextEditingController(text: '1');
  final _keyController = TextEditingController(text: 'FFFFFFFFFFFF');
  String _keyType = 'A';
  bool _isLoading = false;
  List<Map<String, dynamic>> _blocks = [];
  String _errorMessage = '';

  Future<void> _readSector() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _blocks = [];
    });

    final sectorText = _sectorController.text;
    final keyHex = _keyController.text.toUpperCase();
    
    int? sectorIndex = int.tryParse(sectorText);
    
    if (sectorIndex == null || sectorIndex < 0 || sectorIndex >= (widget.tagData['sectorCount'] ?? 0)) {
      setState(() {
        _errorMessage = 'Invalid sector index.';
        _isLoading = false;
      });
      return;
    }

    if (keyHex.length != 12 || !RegExp(r'^[0-9A-F]+$').hasMatch(keyHex)) {
      setState(() {
        _errorMessage = 'Key must be exactly 12 HEX characters.';
        _isLoading = false;
      });
      return;
    }

    try {
      final blocks = await NfcService.readSector(sectorIndex, _keyType, keyHex);
      setState(() {
        _blocks = blocks;
      });
      await LogService.logOperation(widget.tagData['uid'], 'Read Sector', 'Sector $sectorIndex', 'SUCCESS');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      await LogService.logOperation(widget.tagData['uid'], 'Read Sector', 'Sector $sectorIndex', 'FAILED');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _sectorController,
                  decoration: const InputDecoration(labelText: 'Sector'),
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _keyType,
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('Key A')),
                  DropdownMenuItem(value: 'B', child: Text('Key B')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _keyType = val);
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _keyController,
                  decoration: const InputDecoration(labelText: 'Key (HEX)'),
                  maxLength: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _readSector,
            child: _isLoading ? const CircularProgressIndicator() : const Text('Read Sector'),
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _blocks.length,
              itemBuilder: (context, index) {
                final block = _blocks[index];
                return Card(
                  child: ListTile(
                    title: Text('Block ${block['blockIndex']}'),
                    subtitle: Text('HEX: ${block['hex']}\nASCII: ${block['ascii']}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
