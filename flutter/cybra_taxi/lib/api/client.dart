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
