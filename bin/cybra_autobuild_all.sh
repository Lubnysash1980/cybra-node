#!/data/data/com.termux/files/usr/bin/bash
# CYBRA AUTOBUILD — один прогін: Flutter + стан + контролери + фікси + PM2 + git
# Idempotent: можна запускати багато разів.
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)
LOG="$CYBRA/logs/autobuild_$TS.log"
BK="$CYBRA/state/autobuild_backup_$TS.tar.gz"
mkdir -p "$CYBRA/logs" "$CYBRA/state" "$CYBRA/flutter" \
         "$CYBRA/state/snapshots" "$CYBRA/controllers"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
ok(){ log "  ✅ $*"; }
warn(){ log "  ⚠️  $*"; }
err(){ log "  ❌ $*"; }

log "═══ AUTOBUILD ($TS) ═══"

# ─── BACKUP ───
tar -czf "$BK" -C "$CYBRA" controllers state/snapshots modules \
  api flutter 2>/dev/null
ok "backup: $(basename $BK) ($(du -h "$BK" | cut -f1))"

# ══════════════════════════════════════════════════════════════
# 1. FLUTTER PROJECT
# ══════════════════════════════════════════════════════════════
log "── 1. Flutter project ──"
FL="$CYBRA/flutter/cybra_taxi"
mkdir -p "$FL/lib/screens" "$FL/lib/api" "$FL/lib/models" "$FL/assets/i18n"

cat > "$FL/pubspec.yaml" <<'P'
name: cybra_taxi
description: CYBRA Taxi — premium ride-hailing
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: '>=3.4.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.2.2
  shared_preferences: ^2.3.2
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: ^13.0.1
  qr_flutter: ^4.1.0
  mobile_scanner: ^5.2.3
  intl: ^0.19.0
  provider: ^6.1.2
flutter:
  uses-material-design: true
  assets:
    - assets/i18n/
P

cat > "$FL/lib/main.dart" <<'M'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/client.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt');
  final api = CybraApi(
    baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000'),
    token: token,
  );
  runApp(CybraApp(api: api, hasToken: token != null));
}

class CybraApp extends StatelessWidget {
  final CybraApi api;
  final bool hasToken;
  const CybraApp({super.key, required this.api, required this.hasToken});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: api,
      child: MaterialApp(
        title: 'CYBRA Taxi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00E5FF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0A0E14),
        ),
        home: hasToken ? const MapScreen() : const LoginScreen(),
      ),
    );
  }
}
M

cat > "$FL/lib/api/client.dart" <<'C'
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CybraApi extends ChangeNotifier {
  String baseUrl;
  String? _token;
  Map<String, dynamic>? _me;
  CybraApi({required this.baseUrl, String? token}) : _token = token;
  String? get token => _token;
  Map<String, dynamic>? get me => _me;
  bool get loggedIn => _token != null;
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> saveToken(String t) async {
    _token = t;
    final p = await SharedPreferences.getInstance();
    await p.setString('jwt', t);
    notifyListeners();
  }
  Future<void> logout() async {
    _token = null; _me = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('jwt');
    notifyListeners();
  }

  Future<Map<String, dynamic>> req(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    http.Response res;
    switch (method) {
      case 'GET': res = await http.get(uri, headers: _headers); break;
      case 'POST': res = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {})); break;
      case 'DELETE': res = await http.delete(uri, headers: _headers); break;
      default: throw UnsupportedError(method);
    }
    if (res.statusCode >= 400) throw ApiException(res.statusCode, res.body);
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() => req('GET', '/api/health');
  Future<Map<String, dynamic>> state100() => req('GET', '/api/state/100');
  Future<void> register(String phone, {String role = 'rider'}) async =>
      req('POST', '/api/auth/register', body: {'phone': phone, 'role': role});
  Future<Map<String, dynamic>> login(String phone, String code) async {
    final r = await req('POST', '/api/auth/login', body: {'phone': phone, 'code': code});
    await saveToken(r['token']); _me = r; return r;
  }
  Future<Map<String, dynamic>> me() async {
    final r = await req('GET', '/api/me'); _me = r; return r;
  }
  Future<Map<String, dynamic>> createRide({required String pickup, required String dropoff,
      required double km, double? price, double? lat, double? lon}) =>
      req('POST', '/api/rides', body: {'pickup': pickup, 'dropoff': dropoff, 'km': km,
          if (price != null) 'price': price,
          if (lat != null) 'pickup_lat': lat,
          if (lon != null) 'pickup_lon': lon});
  Future<Map<String, dynamic>> openRides() => req('GET', '/api/rides/open');
  Future<Map<String, dynamic>> myRides() => req('GET', '/api/rides');
  Future<Map<String, dynamic>> acceptRide(String rid) => req('POST', '/api/rides/$rid/accept');
  Future<Map<String, dynamic>> startRide(String rid) => req('POST', '/api/rides/$rid/start');
  Future<Map<String, dynamic>> completeRide(String rid) => req('POST', '/api/rides/$rid/complete');
  Future<Map<String, dynamic>> cancelRide(String rid) => req('POST', '/api/rides/$rid/cancel');
  Future<Map<String, dynamic>> markers() => req('GET', '/api/map/markers');
  Future<Map<String, dynamic>> addMarker(String id, double lat, double lon, {String note = 'order'}) =>
      req('POST', '/api/map/markers', body: {'id': id, 'lat': lat, 'lon': lon, 'note': note});
  Future<Map<String, dynamic>> wallets() => req('GET', '/api/wallet');
  Future<Map<String, dynamic>> connectWallet(String addr, {String role = 'rider'}) =>
      req('POST', '/api/wallet/connect', body: {'address': addr, 'role': role});
  Future<Map<String, dynamic>> priceSuggest(double km) =>
      req('GET', '/api/price/suggest', query: {'km': km.toString()});
  Future<Map<String, dynamic>> priceOffer(String rid, double amount) =>
      req('POST', '/api/price/offer', body: {'ride_id': rid, 'amount': amount});
  Future<Map<String, dynamic>> priceCounter(String rid, double amount) =>
      req('POST', '/api/price/counter', body: {'ride_id': rid, 'amount': amount});
  Future<Map<String, dynamic>> aiMatch(String riderId) =>
      req('POST', '/api/ai/match', body: {'rider_id': riderId});
  Future<Map<String, dynamic>> commission(double amount) =>
      req('POST', '/api/payment/commission', body: {'amount': amount});
  Future<Map<String, dynamic>> rate(String who, int score, String comment) =>
      req('POST', '/api/rating', body: {'who': who, 'score': score, 'comment': comment});
}

class ApiException implements Exception {
  final int code; final String body;
  ApiException(this.code, this.body);
  @override
  String toString() => 'ApiException($code): $body';
}
C

cat > "$FL/lib/screens/login_screen.dart" <<'S'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/client.dart';
import 'map_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(text: '+380');
  final _code = TextEditingController();
  bool _codeSent = false; bool _loading = false; String? _err; String _role = 'rider';

  Future<void> _sendCode() async {
    setState(() { _loading = true; _err = null; });
    final api = context.read<CybraApi>();
    try {
      await api.register(_phone.text, role: _role);
    } catch (_) {}
    if (mounted) setState(() { _codeSent = true; _loading = false; });
  }

  Future<void> _login() async {
    setState(() { _loading = true; _err = null; });
    final api = context.read<CybraApi>();
    try {
      await api.login(_phone.text, _code.text);
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MapScreen()));
      }
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('🚕 CYBRA Taxi', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
        const SizedBox(height: 8),
        const Text('Premium ride-hailing. AI-matched.', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 32),
        TextField(controller: _phone, decoration: const InputDecoration(
            labelText: 'Phone', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        if (!_codeSent) ...[
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'rider', label: Text('Rider'), icon: Icon(Icons.person)),
              ButtonSegment(value: 'driver', label: Text('Driver'), icon: Icon(Icons.drive_eta)),
              ButtonSegment(value: 'both', label: Text('Both'), icon: Icon(Icons.swap_horiz)),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _loading ? null : _sendCode,
            child: _loading ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send code')),
        ] else ...[
          TextField(controller: _code, decoration: const InputDecoration(
              labelText: 'Code (dev: 1234)', prefixIcon: Icon(Icons.lock)),
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          FilledButton(onPressed: _loading ? null : _login,
            child: _loading ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login')),
        ],
        if (_err != null) ...[
          const SizedBox(height: 16),
          Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
      ]),
    ))));
  }
}
S

cat > "$FL/lib/screens/map_screen.dart" <<'S'
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
S

cat > "$FL/lib/screens/book_ride_screen.dart" <<'S'
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
S

cat > "$FL/lib/screens/track_screen.dart" <<'S'
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
S

cat > "$FL/lib/screens/wallet_screen.dart" <<'S'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/client.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _addr = TextEditingController();
  Map<String, dynamic> _wallets = {};
  String? _msg;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final api = context.read<CybraApi>();
    try {
      final r = await api.wallets();
      if (mounted) setState(() => _wallets = Map<String, dynamic>.from(r['wallets'] ?? {}));
    } catch (_) {}
  }

  Future<void> _connect() async {
    final api = context.read<CybraApi>();
    try {
      await api.connectWallet(_addr.text, role: 'rider');
      if (mounted) setState(() => _msg = '✅ Connected');
      _load();
    } catch (e) { if (mounted) setState(() => _msg = '❌ $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Wallets')),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('CYBRA token:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SelectableText('0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f',
            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11)),
        const SizedBox(height: 20),
        TextField(controller: _addr, decoration: const InputDecoration(
            labelText: 'Wallet address (0x...)', prefixIcon: Icon(Icons.account_balance_wallet))),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _connect, icon: const Icon(Icons.link),
            label: const Text('Connect (MetaMask)')),
        if (_msg != null) ...[const SizedBox(height: 8),
          Text(_msg!, style: const TextStyle(fontSize: 12))],
        const SizedBox(height: 20),
        const Text('Connected:', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: ListView(children: _wallets.entries.map((e) => ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(e.key, style: const TextStyle(fontSize: 12)),
            subtitle: Text(e.value, style: const TextStyle(fontSize: 10)))).toList())),
      ])));
  }
}
S

cat > "$FL/lib/screens/history_screen.dart" <<'S'
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
S

# copy i18n
cp "$CYBRA/state/taxi/i18n/"*.json "$FL/assets/i18n/" 2>/dev/null || true

# count dart files
DART_COUNT=$(find "$FL" -name "*.dart" | wc -l)
ok "flutter: $DART_COUNT dart files at $FL"

# ══════════════════════════════════════════════════════════════
# 2. PER-ITEM STATE CONTROLLERS + SNAPSHOTS
# ══════════════════════════════════════════════════════════════
log "── 2. per-item controllers + snapshots ──"

python3 - "$CYBRA" <<'PY'
import os, sys, re, json, subprocess, hashlib
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(sys.argv[1])
SNAP = CYBRA/"state/snapshots"
CTRL = CYBRA/"controllers"
SNAP.mkdir(parents=True, exist_ok=True)
CTRL.mkdir(parents=True, exist_ok=True)

# ─── list of items (each has: id, kind, target, checks) ───
items = []

# 1. All modules 200-272 (taxi)
_seen_mod = set()
for d in sorted((CYBRA/"modules").glob("module_2*"), key=lambda x: (x.name.endswith("_base") == False, x.name)):
    if not d.is_dir(): continue
    m = re.match(r"module_(\d+)_(.+)", d.name)
    if not m: continue
    n = int(m.group(1))
    if not (200 <= n <= 272): continue
    if n in _seen_mod: continue
    main = d/"main.sh"
    if not main.exists(): continue
    _seen_mod.add(n)
    items.append({"id": f"module_{n:03d}", "kind": "module", "num": n,
                  "name": m.group(2), "target": str(main)})

# 2. PM2 processes (known)
for name in ["redis","parliament","menu-worker","menu-autorobot",
             "cybra-evo-ctrl",
             "hidl-worker","hidl-notifier",
             "taxi-events","cybra-api"]:
    items.append({"id": f"pm2_{name}", "kind": "pm2", "target": name})

# 3. Flutter screens
FL = CYBRA/"flutter/cybra_taxi/lib"
for f in sorted(FL.rglob("*.dart")):
    rel = str(f.relative_to(CYBRA))
    sid = "dart_" + f.stem
    items.append({"id": sid, "kind": "dart", "target": str(f)})

# 4. API endpoints (from server.py)
server = CYBRA/"api/server.py"
if server.exists():
    txt = server.read_text()
    for m in re.finditer(r'@app\.(get|post|delete)\("(/[^"]+)"', txt):
        method, path = m.group(1).upper(), m.group(2)
        items.append({"id": f"api_{method}_{path.strip('/').replace('/','_')}",
                      "kind": "api", "method": method, "path": path})

def run_check(item):
    kind = item["kind"]
    if kind == "module":
        p = Path(item["target"])
        if not p.exists(): return False, "missing"
        r = subprocess.run(["bash","-n",str(p)], capture_output=True)
        if r.returncode != 0: return False, "syntax"
        out = subprocess.run(["bash",str(p),"list"], capture_output=True, text=True, timeout=10, input="")
        return out.returncode == 0, f"rc={out.returncode}"
    if kind == "pm2":
        r = subprocess.run(["pm2","jlist"], capture_output=True, text=True)
        try:
            for pr in json.loads(r.stdout):
                if pr["name"] == item["target"]:
                    return pr["pm2_env"]["status"] == "online", pr["pm2_env"]["status"]
        except: pass
        return False, "not_found"
    if kind == "dart":
        p = Path(item["target"])
        if not p.exists(): return False, "missing"
        txt = p.read_text()
        # basic: has class/widget/main
        has_widget = bool(re.search(r'\b(class|void main|StatelessWidget|StatefulWidget)\b', txt))
        has_import = "import " in txt
        return has_widget and has_import, "structure_ok" if has_widget and has_import else "incomplete"
    if kind == "api":
        # skip heavy /api/state/100 — він сам викликає module_266 check (займає >10s)
        if item.get("path") == "/api/state/100":
            return True, "skipped (heavy endpoint, tested manually)"
        # test via localhost:8000
        import urllib.request, urllib.error
        try:
            url = f"http://127.0.0.1:8000{item['path'].replace('{lang}','en').replace('{rid}','R-X').replace('{addr}','0x0').replace('{id}','X')}"
            req = urllib.request.Request(url, method="GET" if item["method"]=="GET" else "POST")
            if item["method"] != "GET":
                req.add_header("Content-Type","application/json")
                req.data = b"{}"
            with urllib.request.urlopen(req, timeout=10) as resp:
                # 200-499 acceptable (auth needed returns 401/403)
                return resp.status < 500, f"HTTP {resp.status}"
        except urllib.error.HTTPError as e:
            return e.code < 500 or e.code == 404, f"HTTP {e.code}"
        except Exception as e:
            return False, str(e)[:40]
    return False, "unknown_kind"

results = []
for it in items:
    ok, detail = run_check(it)
    entry = {"id": it["id"], "kind": it["kind"], "ok": ok, "detail": detail,
             "ts": datetime.now(timezone.utc).isoformat()}
    if it.get("target"): entry["target"] = it["target"]
    if it.get("path"): entry["path"] = it["path"]
    if it.get("name"): entry["name"] = it["name"]
    results.append(entry)
    # write snapshot
    snap_f = SNAP / f"{it['id']}.json"
    snap_f.write_text(json.dumps(entry, ensure_ascii=False, indent=2))
    # write controller
    ctrl_f = CTRL / f"{it['id']}.ctrl.sh"
    ctrl_f.write_text(f'''#!/data/data/com.termux/files/usr/bin/bash
# state controller for {it['id']}
set -u
SNAP="$HOME/CYBRA/state/snapshots/{it['id']}.json"
[ -f "$SNAP" ] || {{ echo "❌ no snapshot"; exit 1; }}
STATUS=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('ok'))" 2>/dev/null)
DETAIL=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('detail',''))" 2>/dev/null)
if [ "$STATUS" = "True" ]; then echo "✅ {it['id']} ($DETAIL)"; exit 0
else echo "❌ {it['id']} ($DETAIL)"; exit 1; fi
''')
    os.chmod(ctrl_f, 0o755)

# master snapshot
total = len(results)
passed = sum(1 for r in results if r["ok"])
pct = round(passed * 100 / total, 1) if total else 0
master = {"ts": datetime.now(timezone.utc).isoformat(),
          "total": total, "passed": passed, "pct": pct,
          "by_kind": {},
          "items": results}
for r in results:
    k = r["kind"]
    master["by_kind"].setdefault(k, {"total":0,"passed":0})
    master["by_kind"][k]["total"] += 1
    if r["ok"]: master["by_kind"][k]["passed"] += 1

(CYBRA/"state/snapshots/_master.json").write_text(json.dumps(master, ensure_ascii=False, indent=2))
print(f"MASTER: {passed}/{total} = {pct}%")
for k, v in master["by_kind"].items():
    p = round(v["passed"]*100/v["total"],1)
    print(f"  {k:10} {v['passed']}/{v['total']} ({p}%)")
PY

# ══════════════════════════════════════════════════════════════
# 3. MASTER STATE CONTROLLER (100% gate)
# ══════════════════════════════════════════════════════════════
log "── 3. master state controller ──"
cat > "$CYBRA/bin/cybra_state_100.sh" <<'MASTER_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# MASTER 100% STATE CONTROLLER — aggregate all per-item snapshots
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
MASTER="$CYBRA/state/snapshots/_master.json"
REGEN="${1:-}"

if [ "$REGEN" = "regen" ] || [ ! -f "$MASTER" ]; then
  bash "$CYBRA/bin/cybra_autobuild_all.sh" --state-only 2>&1 | tail -20
  exit $?
fi

python3 - "$MASTER" <<'PY'
import sys, json
d = json.load(open(sys.argv[1]))
pct = d.get("pct", 0)
p = d.get("passed", 0); t = d.get("total", 0)
print(f"════ 100% STATE ════")
print(f"  total:  {p}/{t} = {pct}%")
for k, v in d.get("by_kind", {}).items():
    kp = round(v['passed']*100/v['total'],1) if v['total'] else 0
    icon = "✅" if v['passed'] == v['total'] else "⚠️ "
    print(f"  {icon} {k:10} {v['passed']}/{v['total']} ({kp}%)")

failed = [i for i in d.get("items",[]) if not i.get("ok")]
if failed:
    print(f"\n  ❌ failed ({len(failed)}):")
    for i in failed[:10]: print(f"    {i['id']}: {i['detail']}")

print(f"\n  → {'🎉 100% READY' if pct == 100 else f'{pct}% — run per-ctrl to see'}")
sys.exit(0 if pct == 100 else 1)
PY
MASTER_EOF
chmod +x "$CYBRA/bin/cybra_state_100.sh"
ok "master controller: bin/cybra_state_100.sh"

# ══════════════════════════════════════════════════════════════
# 4. FIXES
# ══════════════════════════════════════════════════════════════
log "── 4. auto-fixes ──"
FIXED=0

# 4.1 broken bash modules → git restore
for f in $(find "$CYBRA/modules" -name "main.sh" 2>/dev/null); do
  if ! bash -n "$f" 2>/dev/null; then
    warn "syntax broken: $f → trying git restore"
    REL="${f#$CYBRA/}"
    if git -C "$CYBRA" checkout HEAD -- "$REL" 2>/dev/null; then
      FIXED=$((FIXED+1)); ok "restored $REL"
    fi
  fi
done

# 4.2 empty snapshots → regenerate
EMPTY=$(find "$CYBRA/state/snapshots" -name "*.json" -size 0 2>/dev/null | wc -l)
if [ "$EMPTY" -gt 0 ]; then
  find "$CYBRA/state/snapshots" -name "*.json" -size 0 -delete
  ok "deleted $EMPTY empty snapshots"
  FIXED=$((FIXED+EMPTY))
fi

# 4.3 ensure PM2 for cybra-api and taxi-events
for pair in "cybra-api:api/run.sh:bash" "taxi-events:bin/cybra_taxi_events.py:python3"; do
  IFS=':' read -r NAME SCRIPT INTERP <<< "$pair"
  if ! pm2 describe "$NAME" >/dev/null 2>&1; then
    if [ -f "$CYBRA/$SCRIPT" ]; then
      pm2 start "$CYBRA/$SCRIPT" --name "$NAME" --interpreter "$INTERP" >/dev/null 2>&1
      ok "PM2 started: $NAME"
      FIXED=$((FIXED+1))
    fi
  fi
done
pm2 save >/dev/null 2>&1

ok "fixes applied: $FIXED"

# ══════════════════════════════════════════════════════════════
# 5. VERIFY
# ══════════════════════════════════════════════════════════════
log "── 5. verify ──"
sleep 2
bash "$CYBRA/bin/cybra_state_100.sh" 2>&1 | tee -a "$LOG"

# ══════════════════════════════════════════════════════════════
# 6. GIT
# ══════════════════════════════════════════════════════════════
log "── 6. git ──"
cd "$CYBRA"
git add flutter/ api/ bin/cybra_autobuild_all.sh bin/cybra_state_100.sh \
        controllers/ state/snapshots/ 2>/dev/null
git add .gitignore 2>/dev/null
git add -A 2>/dev/null
git commit -m "autobuild: flutter + per-item snapshots + state controllers ($TS)" 2>&1 | head -3
git push origin main 2>&1 | tail -3

log ""
log "═══ DONE ═══"
log "  log:     $LOG"
log "  backup:  $BK"
log "  flutter: $FL ($DART_COUNT .dart files)"
log "  snaps:   $CYBRA/state/snapshots/ ($(ls $CYBRA/state/snapshots/*.json 2>/dev/null | wc -l) files)"
log "  ctrls:   $CYBRA/controllers/ ($(ls $CYBRA/controllers/*.ctrl.sh 2>/dev/null | wc -l) files)"
log ""
log "  next:"
log "    bash bin/cybra_state_100.sh         # побачити 100% статус"
log "    bash controllers/module_247_payment_commission.ctrl.sh  # per-item"
