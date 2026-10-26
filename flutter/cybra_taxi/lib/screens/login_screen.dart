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
