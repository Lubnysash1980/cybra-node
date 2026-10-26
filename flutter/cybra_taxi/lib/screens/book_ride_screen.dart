import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/client.dart';

class BookRideScreen extends StatefulWidget {
  const BookRideScreen({super.key});
  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final _pickup = TextEditingController(text: 'Хрещатик');
  final _dropoff = TextEditingController(text: 'Аеропорт');
  double _km = 15;
  double? _price;
  Map<String, dynamic>? _suggest;
  bool _loading = false;
  String? _result;

  @override
  void initState() { super.initState(); _updatePrice(); }

  Future<void> _updatePrice() async {
    final api = context.read<CybraApi>();
    final r = await api.priceSuggest(_km);
    if (mounted) setState(() {
      _suggest = r;
      _price = (r['base'] as num?)?.toDouble();
    });
  }

  Future<void> _book() async {
    setState(() { _loading = true; _result = null; });
    final api = context.read<CybraApi>();
    try {
      final r = await api.createRide(pickup: _pickup.text, dropoff: _dropoff.text, km: _km, price: _price);
      final rid = (r['ride'] as Map)['id'];
      setState(() => _result = '✅ Ride: $rid');
    } catch (e) { setState(() => _result = '❌ $e'); }
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final low = (_suggest?['low'] as num?)?.toDouble();
    final high = (_suggest?['high'] as num?)?.toDouble();
    return Scaffold(appBar: AppBar(title: const Text('Book ride')),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: ListView(children: [
        TextField(controller: _pickup, decoration: const InputDecoration(
            labelText: 'Pickup', prefixIcon: Icon(Icons.my_location))),
        const SizedBox(height: 12),
        TextField(controller: _dropoff, decoration: const InputDecoration(
            labelText: 'Dropoff', prefixIcon: Icon(Icons.flag))),
        const SizedBox(height: 20),
        Text('Distance: ${_km.toStringAsFixed(1)} km',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: _km, min: 1, max: 100,
            onChanged: (v) => setState(() => _km = v), onChangeEnd: (_) => _updatePrice()),
        if (_suggest != null) Text(
            'AI suggest: \$${low?.toStringAsFixed(0)} – \$${high?.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(labelText: 'Offer', prefixIcon: Icon(Icons.attach_money)),
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: _price?.toStringAsFixed(0)),
          onChanged: (v) => _price = double.tryParse(v),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _loading ? null : _book,
            icon: _loading ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
            label: const Text('Book now')),
        if (_result != null) ...[
          const SizedBox(height: 20),
          Card(child: Padding(padding: const EdgeInsets.all(12),
              child: Text(_result!, style: const TextStyle(fontSize: 13)))),
        ],
      ]))));
  }
}
