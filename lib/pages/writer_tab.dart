import 'dart:async';
import 'dart:convert';
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
  final _blockController = TextEditingController(text: '5');
  final _dataController = TextEditingController();
  final _keyController = TextEditingController(text: 'FFFFFFFFFFFF');
  String _keyType = 'A';
  String _inputType = 'Text'; // 'Text' or 'HEX'
  bool _isLoading = false;

  StreamSubscription? _writeSub;

  void _promptForCardAndWrite(int blockIndex, String finalHexData, String keyHex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Menunggu Kartu...'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nfc, size: 50, color: Colors.blue),
            SizedBox(height: 16),
            Text('Kartu terlepas. Silakan tempelkan kembali kartu Anda ke belakang HP dan TAHAN sampai selesai.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _writeSub?.cancel();
              Navigator.pop(ctx);
            },
            child: const Text('BATAL'),
          ),
        ],
      ),
    );

    NfcService.startNfcReader();

    _writeSub = NfcService.tagStream.listen((_) async {
      _writeSub?.cancel();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close dialog
      }

      setState(() => _isLoading = true);
      try {
        final success = await NfcService.writeBlock(blockIndex, finalHexData, _keyType, keyHex);
        if (success) {
          await LogService.logOperation(widget.tagData['uid'], 'Write Block', 'Block $blockIndex', 'SUCCESS');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write successful & verified!')));
          }
        }
      } catch (e) {
        await LogService.logOperation(widget.tagData['uid'], 'Write Block', 'Block $blockIndex', 'FAILED');
        if (mounted) _showError(e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _writeBlock() async {
    final blockText = _blockController.text;
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

    if (keyHex.length != 12 || !RegExp(r'^[0-9A-F]+$').hasMatch(keyHex)) {
      _showError('Key must be exactly 12 HEX characters (6 bytes).');
      return;
    }

    String finalHexData = '';

    if (_inputType == 'Text') {
      final textData = _dataController.text;
      if (textData.length > 16) {
        _showError('Text cannot exceed 16 characters.');
        return;
      }
      final bytes = utf8.encode(textData);
      String hexStr = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
      finalHexData = hexStr.padRight(32, '0');
    } else {
      finalHexData = _dataController.text.toUpperCase();
      if (finalHexData.length != 32 || !RegExp(r'^[0-9A-F]+$').hasMatch(finalHexData)) {
        _showError('Data must be exactly 32 HEX characters (16 bytes).');
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Write'),
        content: Text('Are you sure you want to write to Block $blockIndex?\n\nFinal HEX Data:\n$finalHexData'),
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
      final success = await NfcService.writeBlock(blockIndex, finalHexData, _keyType, keyHex);
      if (success) {
        await LogService.logOperation(widget.tagData['uid'], 'Write Block', 'Block $blockIndex', 'SUCCESS');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write successful & verified!')));
        }
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('out of date') || errStr.contains('Tag connection lost') || errStr.contains('NO_TAG') || errStr.contains('SECURITY_ERROR')) {
        _promptForCardAndWrite(blockIndex, finalHexData, keyHex);
      } else {
        await LogService.logOperation(widget.tagData['uid'], 'Write Block', 'Block $blockIndex', 'FAILED');
        _showError(errStr);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _blockController,
              decoration: const InputDecoration(labelText: 'Block Index (Locked to 5)'),
              keyboardType: TextInputType.number,
              readOnly: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DropdownButton<String>(
                  value: _inputType,
                  items: const [
                    DropdownMenuItem(value: 'Text', child: Text('Normal Text')),
                    DropdownMenuItem(value: 'HEX', child: Text('Raw HEX')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _inputType = val;
                        _dataController.clear();
                      });
                    }
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _dataController,
                    decoration: InputDecoration(
                      labelText: _inputType == 'Text' ? 'Data (Max 16 chars)' : 'Data Payload (32 HEX)',
                    ),
                    maxLength: _inputType == 'Text' ? 16 : 32,
                  ),
                ),
              ],
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
