import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../api/client.dart';
import 'book_ride_screen.dart';
import 'wallet_screen.dart';
import 'history_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  List<Map<String, dynamic>> _markers = [];
  List<Map<String, dynamic>> _openRides = [];
  final LatLng _center = const LatLng(50.4501, 30.5234);
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<CybraApi>();
    try {
      final m = await api.markers();
      final o = await api.openRides();
      setState(() {
        _markers = (m['markers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _openRides = (o['rides'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      });
    } catch (e) { debugPrint('load: $e'); }
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<CybraApi>();
    return Scaffold(
      appBar: AppBar(title: const Text('CYBRA Taxi'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        IconButton(icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
        IconButton(icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
        IconButton(icon: const Icon(Icons.logout), onPressed: () async {
          await api.logout();
          if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        }),
      ]),
      body: Stack(children: [
        FlutterMap(mapController: _map, options: MapOptions(initialCenter: _center, initialZoom: 13),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cybra.taxi'),
            MarkerLayer(markers: _markers.where((m) => m['lat'] != null).map((m) => Marker(
                point: LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble()),
                width: 40, height: 40,
                child: const Icon(Icons.location_on, color: Color(0xFF00E5FF), size: 40))).toList()),
          ]),
        if (_loading) const Positioned(top: 8, left: 0, right: 0, child: LinearProgressIndicator()),
        Positioned(bottom: 16, left: 16, right: 16, child: Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Open rides: ${_openRides.length}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Markers: ${_markers.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookRideScreen())),
                  icon: const Icon(Icons.add_location), label: const Text('Book ride'))),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh)),
            ]),
          ]),
        ))),
      ]),
    );
  }
}
