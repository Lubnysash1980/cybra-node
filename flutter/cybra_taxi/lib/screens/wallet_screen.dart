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
