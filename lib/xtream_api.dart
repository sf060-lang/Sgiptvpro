import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

dynamic _decode(Uint8List b) => jsonDecode(utf8.decode(b, allowMalformed: true));

/// Xtream Codes player_api.php istemcisi.
class XtreamApi {
  XtreamApi(this.acc);
  final Account acc;

  /// Bircok IPTV sunucusu VLC kimligini sorunsuz kabul eder.
  static const ua = 'VLC/3.0.20 LibVLC/3.0.20';

  Uri _u([Map<String, String> q = const {}]) =>
      Uri.parse('${acc.base}/player_api.php').replace(queryParameters: {
        'username': acc.username,
        'password': acc.password,
        ...q,
      });

  Future<dynamic> _get([Map<String, String> q = const {}]) async {
    final r = await http
        .get(_u(q), headers: {'User-Agent': ua}).timeout(const Duration(seconds: 90));
    if (r.statusCode != 200) {
      throw Exception('Sunucu hatası (HTTP ${r.statusCode})');
    }
    // Buyuk listeleri (20-50 bin kayit) arayuzu dondurmadan ayristir.
    return compute(_decode, r.bodyBytes);
  }

  Future<Map<String, dynamic>> authenticate() async {
    final d = await _get();
    if (d is! Map || d['user_info'] is! Map) {
      throw Exception('Sunucu geçerli bir Xtream Codes yanıtı vermedi.');
    }
    final ui = Map<String, dynamic>.from(d['user_info'] as Map);
    if ('${ui['auth']}' != '1') {
      throw Exception('Kullanıcı adı veya şifre hatalı.');
    }
    final st = '${ui['status'] ?? ''}';
    if (st.isNotEmpty && st.toLowerCase() != 'active') {
      throw Exception('Hesap aktif değil: $st');
    }
    return ui;
  }

  String _catAction(MediaType t) => switch (t) {
        MediaType.live => 'get_live_categories',
        MediaType.movie => 'get_vod_categories',
        MediaType.series => 'get_series_categories',
      };

  String _listAction(MediaType t) => switch (t) {
        MediaType.live => 'get_live_streams',
        MediaType.movie => 'get_vod_streams',
        MediaType.series => 'get_series',
      };

  Future<List<Category>> categories(MediaType t) async {
    final d = await _get({'action': _catAction(t)});
    if (d is! List) return [];
    return [
      for (final m in d)
        if (m is Map)
          Category('${m['category_id']}', str(m['category_name']) ?? '?'),
    ];
  }

  Future<List<Item>> items(MediaType t) async {
    final d = await _get({'action': _listAction(t)});
    if (d is! List) return [];
    return [
      for (final m in d)
        if (m is Map) Item.fromApi(t, m),
    ];
  }

  Future<SeriesInfo> seriesInfo(Item s) async {
    final d = await _get({'action': 'get_series_info', 'series_id': s.id});
    final seasons = <int, List<Episode>>{};

    void add(int sn, dynamic list) {
      if (list is! List) return;
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (e is! Map) continue;
        final info = e['info'];
        final num = int.tryParse('${e['episode_num']}') ?? (i + 1);
        final season = int.tryParse('${e['season']}') ?? sn;
        seasons.putIfAbsent(season, () => []).add(Episode(
              id: '${e['id']}',
              title: str(e['title']) ?? 'Bölüm $num',
              ext: str(e['container_extension']) ?? 'mp4',
              season: season,
              num: num,
              icon: info is Map ? str(info['movie_image']) : null,
            ));
      }
    }

    if (d is Map) {
      final eps = d['episodes'];
      if (eps is Map) {
        eps.forEach((k, v) => add(int.tryParse('$k') ?? 1, v));
      } else if (eps is List) {
        for (var i = 0; i < eps.length; i++) {
          add(i + 1, eps[i]);
        }
      }
    }
    for (final l in seasons.values) {
      l.sort((a, b) => a.num.compareTo(b.num));
    }

    final info = (d is Map && d['info'] is Map) ? d['info'] as Map : const {};
    return SeriesInfo(
      plot: str(info['plot']),
      cover: str(info['cover']),
      genre: str(info['genre']),
      rating: str(info['rating']),
      seasons: Map.fromEntries(
          seasons.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
    );
  }

  String urlFor(PlayEntry e, String liveFmt) {
    final u = Uri.encodeComponent(acc.username);
    final p = Uri.encodeComponent(acc.password);
    switch (e.type) {
      case MediaType.live:
        return '${acc.base}/live/$u/$p/${e.id}.$liveFmt';
      case MediaType.movie:
        return '${acc.base}/movie/$u/$p/${e.id}.${e.ext ?? 'mp4'}';
      case MediaType.series:
        return '${acc.base}/series/$u/$p/${e.id}.${e.ext ?? 'mp4'}';
    }
  }
}
