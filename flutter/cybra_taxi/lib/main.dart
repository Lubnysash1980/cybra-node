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
