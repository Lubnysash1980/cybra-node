import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/client.dart';

class TrackScreen extends StatefulWidget {
  final String rideId;
  const TrackScreen({super.key, required this.rideId});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  Map<String, dynamic>? _ride;
  @override
  void initState() { super.initState(); _poll(); }

  Future<void> _poll() async {
    final api = context.read<CybraApi>();
    for (var i = 0; i < 60 && mounted; i++) {
      try {
        final r = await api.req('GET', '/api/rides/${widget.rideId}');
        if (mounted) setState(() => _ride = r);
        if (r['status'] == 'completed' || r['status'] == 'cancelled') break;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('Ride ${widget.rideId}')),
      body: Center(child: _ride == null ? const CircularProgressIndicator()
        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Status: ${_ride!['status']}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('From: ${_ride!['pickup']}'),
          Text('To:   ${_ride!['dropoff']}'),
          Text('Price: \$${_ride!['price']}'),
          if (_ride!['driver'] != null) Text('Driver: ${_ride!['driver']}'),
        ])),
    );
  }
}
