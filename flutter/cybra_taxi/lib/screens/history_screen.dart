import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/client.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _rides = [];
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final api = context.read<CybraApi>();
    try {
      final r = await api.myRides();
      if (mounted) setState(() => _rides = (r['rides'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (_) {}
  }

  Color _sc(String s) {
    switch (s) { case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'in_progress': return Colors.orange;
      case 'accepted': return Colors.blue;
      default: return Colors.white54; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('History'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _rides.isEmpty ? const Center(child: Text('No rides yet',
          style: TextStyle(color: Colors.white54)))
        : ListView.builder(padding: const EdgeInsets.all(12),
            itemCount: _rides.length, itemBuilder: (_, i) {
              final r = _rides[i];
              return Card(child: ListTile(
                leading: Icon(Icons.local_taxi, color: _sc(r['status'] ?? '')),
                title: Text('${r['pickup']} → ${r['dropoff']}'),
                subtitle: Text('${r['status']} · \$${r['price']}',
                    style: TextStyle(color: _sc(r['status'] ?? ''))),
                trailing: Text(r['id']?.toString().substring(0, 8) ?? '',
                    style: const TextStyle(fontSize: 10, color: Colors.white30)),
              ));
            }));
  }
}
