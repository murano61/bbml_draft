import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/build_model.dart';

class BuildApiService {
  final http.Client _client;
  final String baseUrl = 'https://bbmlbuild.biz.tr/api';
  BuildApiService._(this._client);
  static BuildApiService create() => BuildApiService._(http.Client());
  Future<List<BuildModel>> _decodeList(http.Response res){
    if (res.statusCode != 200) return Future.value(const []);
    final data = jsonDecode(res.body);
    if (data is List) {
      return Future.value(data.map((e)=> BuildModel.fromJson(Map<String, dynamic>.from(e))).toList());
    }
    if (data is Map && data['data'] is List) {
      final l = List<Map<String, dynamic>>.from(data['data']);
      return Future.value(l.map((e)=> BuildModel.fromJson(e)).toList());
    }
    return Future.value(const []);
  }
  Future<List<BuildModel>> getBuildsByHero({String? heroId, String? heroName}) async {
    final out = <BuildModel>[];
    final paths = <String>[];
    if (heroId != null && heroId.isNotEmpty) {
      paths.add('/builds?heroId=$heroId');
      paths.add('/heroBuilds?heroId=$heroId');
      paths.add('/builds/hero/$heroId');
      paths.add('/heroes/$heroId/builds');
    }
    if (heroName != null && heroName.isNotEmpty) {
      final q = Uri.encodeQueryComponent(heroName);
      paths.add('/builds?heroName=$q');
      paths.add('/heroBuilds?heroName=$q');
    }
    for (final p in paths) {
      try {
        final res = await _client.get(Uri.parse(baseUrl + p)).timeout(const Duration(seconds: 8));
        final list = await _decodeList(res);
        if (list.isNotEmpty) { out.addAll(list); break; }
      } catch (_) {}
    }
    return out;
  }
  Future<List<BuildModel>> getAllBuilds() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/builds')).timeout(const Duration(seconds: 8));
      return _decodeList(res);
    } catch (_) { return const []; }
  }
  Future<BuildModel?> getRandomBuild() async {
    final paths = ['/builds/random', '/heroBuilds/random'];
    for (final p in paths) {
      try {
        final res = await _client.get(Uri.parse(baseUrl + p)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map) { return BuildModel.fromJson(Map<String, dynamic>.from(data)); }
          if (data is List && data.isNotEmpty) { return BuildModel.fromJson(Map<String, dynamic>.from(data.first)); }
        }
      } catch (_) {}
    }
    return null;
  }
}
