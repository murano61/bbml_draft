import 'dart:convert';
import 'package:http/http.dart' as http;

class ItemModel {
  final int id;
  final String name;
  final String? imageUrl;
  final String? shortDescription;
  final String? description;
  final String? category;
  final String? buffType;
  ItemModel({required this.id, required this.name, this.imageUrl, this.shortDescription, this.description, this.category, this.buffType});
  factory ItemModel.fromJson(Map<String, dynamic> j){
    return ItemModel(
      id: (j['id'] is int) ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      name: (j['name'] ?? j['itemName'] ?? '').toString(),
      imageUrl: (j['imageUrl'] ?? j['image'] ?? j['icon'])?.toString(),
      shortDescription: (j['shortDescription'] ?? j['shortDesc'] ?? '').toString(),
      description: (j['description'] ?? j['desc'] ?? '').toString(),
      category: (j['category'] ?? j['type'] ?? '').toString(),
      buffType: (j['buffType'] ?? j['buff'] ?? '').toString(),
    );
  }
}

class ItemApiService {
  final http.Client _client;
  final String baseUrl = 'https://bbmlbuild.biz.tr/api';
  List<ItemModel> _cache = const [];
  Map<String, ItemModel> _index = const {};
  bool _apiOk = false;
  final Map<String, String> _syn = const {
    'magicshoes': 'Sihirli Ayakkabılar',
    'swiftboots': 'Sihirli Ayakkabılar',
    'magicboots': 'Sihirli Ayakkabılar',
    'bladeofdespair': 'Umutsuzluk Kılıcı',
    'immortality': 'Ölümsüzlük',
    'windtalker': 'Rüzgar Konuşan',
  };
  final String _placeholder = 'https://via.placeholder.com/56x56/1a0f23/ffffff?text=%20';
  ItemApiService._(this._client);
  static ItemApiService create() => ItemApiService._(http.Client());
  String _norm(String s){
    final t = s.toLowerCase().trim();
    final r = t
        .replaceAll('ç','c')
        .replaceAll('ğ','g')
        .replaceAll('ı','i')
        .replaceAll('i̇','i')
        .replaceAll('ö','o')
        .replaceAll('ş','s')
        .replaceAll('ü','u')
        .replaceAll(RegExp(r"[^a-z0-9]+"), '');
    return r;
  }
  Future<void> ensureCache() async {
    if (_cache.isNotEmpty) return;
    try {
      final res = await _client.get(Uri.parse('$baseUrl/items')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          _cache = data.map((e)=> ItemModel.fromJson(Map<String, dynamic>.from(e))).toList();
          _apiOk = _cache.isNotEmpty;
        }
      }
    } catch (_) {}
    if (_cache.isEmpty) {
      _cache = [
        ItemModel(id: 101, name: 'Sihirli Ayakkabılar', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCadx3sNAR8F1PzL7zW6phI7YI_wUeQQtt9oSiuSx9HkOYiHinZgCUM7AF3s5mdsMPzV169KRgS5qWz03vzEcq6FYW4qPyZmPQkJ8u-2i0gb7Bli28PJFxtLAWVleM7hTHduRR3fsvvyknjKF_mQKlD_qILUo7fdmnVI18k9VmdHzey2Pw4llGu5KbxSIUblvFgtetWNNP1jlg4-IQ8T37DkTkeloZ8C2yK1ljmeVa5bzGozNO6Pt3awbPfYgDKyh-_iyEdIw6aGaq4'),
        ItemModel(id: 102, name: 'Umutsuzluk Kılıcı', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBRvATc52BTTMNIqsWUWuOSziz2fa7vBPd9c9gn0QiwH2Smda2kLQ7i3Mv-ZaUFXivgqGLYGbIsbgFf0yxjHWZ7QAY4Cub5fqkf87oZC0Qx_LcgDTeWLRJGrJ1vYqVnN_qOzA_vZTpODTF1HTfM-7NeXWqoYXcjD6bnChrnDbPGBB7TAmowPTOWcc-v4EnBYa62JpHnAcxHPo4uVSZzWfILcqXqAny6KKJ_ObF6DMI4HMgmPZLQeoQtnQPJIQ2fOa5omMPxNAAwD2T0'),
        ItemModel(id: 103, name: 'Ölümsüzlük', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBRvATc52BTTMNIqsWUWuOSziz2fa7vBPd9c9gn0QiwH2Smda2kLQ7i3Mv-ZaUFXivgqGLYGbIsbgFf0yxjHWZ7QAY4Cub5fqkf87oZC0Qx_LcgDTeWLRJGrJ1vYqVnN_qOzA_vZTpODTF1HTfM-7NeXWqoYXcjD6bnChrnDbPGBB7TAmowPTOWcc-v4EnBYa62JpHnAcxHPo4uVSZzWfILcqXqAny6KKJ_ObF6DMI4HMgmPZLQeoQtnQPJIQ2fOa5omMPxNAAwD2T0'),
        ItemModel(id: 104, name: 'Rüzgar Konuşan', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBRvATc52BTTMNIqsWUWuOSziz2fa7vBPd9c9gn0QiwH2Smda2kLQ7i3Mv-ZaUFXivgqGLYGbIsbgFf0yxjHWZ7QAY4Cub5fqkf87oZC0Qx_LcgDTeWLRJGrJ1vYqVnN_qOzA_vZTpODTF1HTfM-7NeXWqoYXcjD6bnChrnDbPGBB7TAmowPTOWcc-v4EnBYa62JpHnAcxHPo4uVSZzWfILcqXqAny6KKJ_ObF6DMI4HMgmPZLQeoQtnQPJIQ2fOa5omMPxNAAwD2T0'),
        ItemModel(id: 105, name: 'Auro Darbesi', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBPsbEU0ZnhMwcc4JJtrFLuxkf14AzVdHkOsyH98hKu40dzrHbP0LxuQG2YkPCI_NZmW6R07BgRTza1SeHBj7fh3iXlVn8FjA0UvxF3UEKUIMr5y9hDU7B9-eRgobLu4aE271oqnon_ZPRXsvVhhyBxjJPy_C2sGkfIYLQ216n34zZKJVef7V8o96jsnER6_SVfXYUkv3ncSYYz3yUw-gzmpE4Ml0UcipHNDDU9LZ4Hp3o83xzd5eEyLh1KAnVGp5AiOEoTM7GZo34W'),
        ItemModel(id: 106, name: 'Kanatlı Kalkan', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBRvATc52BTTMNIqsWUWuOSziz2fa7vBPd9c9gn0QiwH2Smda2kLQ7i3Mv-ZaUFXivgqGLYGbIsbgFf0yxjHWZ7QAY4Cub5fqkf87oZC0Qx_LcgDTeWLRJGrJ1vYqVnN_qOzA_vZTpODTF1HTfM-7NeXWqoYXcjD6bnChrnDbPGBB7TAmowPTOWcc-v4EnBYa62JpHnAcxHPo4uVSZzWfILcqXqAny6KKJ_ObF6DMI4HMgmPZLQeoQtnQPJIQ2fOa5omMPxNAAwD2T0'),
      ];
    }
    final m = <String, ItemModel>{};
    for (final it in _cache) {
      final n = _norm(it.name);
      if (n.isNotEmpty) m[n] = it;
    }
    _index = m;
  }
  bool get apiOk => _apiOk;
  Future<List<ItemModel>> getAllItems() async { await ensureCache(); return _cache; }
  Future<ItemModel?> getItemById(int id) async { await ensureCache(); return _cache.firstWhere((e)=> e.id==id, orElse: ()=> ItemModel(id: id, name: 'Bulunamadı')); }
  Future<List<ItemModel>> searchItemsByName(String name) async {
    await ensureCache();
    final q = name.toLowerCase();
    final local = _cache.where((e)=> e.name.toLowerCase()==q).toList();
    if (local.isNotEmpty) return local;
    var res = await _client.get(Uri.parse('$baseUrl/items?name=$q'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        return data.map((e)=> ItemModel.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    }
    res = await _client.get(Uri.parse('$baseUrl/items?search=$q'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        return data.map((e)=> ItemModel.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    }
    return [];
  }
  Future<List<ItemModel>> resolveNames(List<String> names) async {
    await ensureCache();
    final out = <ItemModel>[];
    for (final n in names){
      final qNorm = _norm(n);
      final canon = _syn[qNorm] ?? n;
      final canonNorm = _norm(canon);
      ItemModel? match = _index[canonNorm];
      match ??= _cache.firstWhere(
          (e){
            final en = _norm(e.name);
            return en==canonNorm || en.contains(canonNorm) || canonNorm.contains(en);
          },
          orElse: ()=> ItemModel(id: 0, name: canon),
        );
      if (match.id==0) {
        final res = await searchItemsByName(canon);
        match = res.isNotEmpty ? res.first : ItemModel(id: 0, name: canon);
      }
      if ((match.imageUrl??'').isEmpty) {
        match = ItemModel(
          id: match.id,
          name: match.name,
          imageUrl: _placeholder,
          shortDescription: match.shortDescription,
          description: match.description,
          category: match.category,
          buffType: match.buffType,
        );
      }
      out.add(match);
    }
    return out;
  }
}
