import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_app/services/nfc_service.dart';
import 'package:nfc_app/services/log_service.dart';

class WriterTab extends StatefulWidget {
  final Map<String, dynamic> tagData;
  const WriterTab({super.key, required this.tagData});

  @override
  State<WriterTab> createState() => _WriterTabState();
}

class _WriterTabState extends State<WriterTab> {
  final _blockController = TextEditingController();
  final _dataController = TextEditingController();
  final _keyController = TextEditingController(text: 'FFFFFFFFFFFF');
  String _keyType = 'A';
  bool _isLoading = false;

  Future<void> _writeBlock() async {
    final blockText = _blockController.text;
    final dataHex = _dataController.text.toUpperCase();
    final keyHex = _keyController.text.toUpperCase();
    
    int? blockIndex = int.tryParse(blockText);
    
    if (blockIndex == null || blockIndex < 0 || blockIndex >= (widget.tagData['blockCount'] ?? 0)) {
      _showError('Invalid block index.');
      return;
    }

    if (blockIndex == 0) {
      _showError('Cannot write to manufacturer block 0.');
      return;
    }

    if (dataHex.length != 32 || !RegExp(r'^[0-9A-F]+$').hasMatch(dataHex)) {
      _showError('Data must be exactly 32 HEX characters (16 bytes).');
      return;
    }

    if (keyHex.length != 12 || !RegExp(r'^[0-9A-F]+$').hasMatch(keyHex)) {
      _showError('Key must be exactly 12 HEX characters (6 bytes).');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Write'),
        content: Text('Are you sure you want to write to Block $blockIndex?\n\nData:\n$dataHex'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('WRITE')
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await NfcService.writeBlock(blockIndex, dataHex, _keyType, keyHex);
      if (success) {
        await LogService.logOperation(widget.tagData['uid'], 'Write Block', 'Block $blockIndex', 'SUCCESS');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write successful & verified!')));
        }
      }
    } catch (e) {
      await LogService.logOperation(widget.tagData['uid'], 'Write Block', 'Block $blockIndex', 'FAILED');
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _blockController,
              decoration: const InputDecoration(labelText: 'Block Index'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dataController,
              decoration: const InputDecoration(labelText: 'Data Payload (32 HEX characters)'),
              maxLength: 32,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
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
                  child: TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(labelText: 'Key (HEX)'),
                    maxLength: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _writeBlock,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _isLoading ? const CircularProgressIndicator() : const Text('Write Block'),
            ),
          ],
        ),
      ),
    );
  }
}
