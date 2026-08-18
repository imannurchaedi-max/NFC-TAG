import 'package:flutter/material.dart';
import 'package:nfc_app/services/log_service.dart';
import 'package:intl/intl.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<LogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await LogService.getLogs();
    setState(() {
      _logs = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Logs: ${_logs.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await LogService.clearLogs();
                  _loadLogs();
                },
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              final log = _logs[index];
              final date = DateTime.parse(log.timestamp);
              final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
              
              Color statusColor = log.status == 'SUCCESS' ? Colors.green : Colors.red;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('${log.operation} - ${log.target}'),
                  subtitle: Text('UID: ${log.uid}\nTime: $formattedDate'),
                  trailing: Text(log.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
