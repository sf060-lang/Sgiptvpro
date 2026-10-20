enum MediaType { live, movie, series }

MediaType mediaTypeFrom(String? s) =>
    MediaType.values.firstWhere((e) => e.name == s, orElse: () => MediaType.live);

String typeLabel(MediaType t) => switch (t) {
      MediaType.live => 'Canlı',
      MediaType.movie => 'Film',
      MediaType.series => 'Dizi',
    };

/// null / bos / "null" degerlerini null'a cevirir.
String? str(dynamic v) {
  if (v == null) return null;
  final t = '$v'.trim();
  return (t.isEmpty || t == 'null') ? null : t;
}

class Account {
  final String name, host, username, password;
  const Account({
    required this.name,
    required this.host,
    required this.username,
    required this.password,
  });

  String get base {
    var h = host.trim();
    if (!h.startsWith('http://') && !h.startsWith('https://')) h = 'http://$h';
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  String get key => '$base|$username';

  Map<String, dynamic> toJson() =>
      {'name': name, 'host': host, 'username': username, 'password': password};

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        name: '${j['name']}',
        host: '${j['host']}',
        username: '${j['username']}',
        password: '${j['password']}',
      );
}

class Category {
  final String id, name;
  const Category(this.id, this.name);
}

/// Canli kanal, film veya dizi (liste ogesi).
class Item {
  final MediaType type;
  final String id, name, cat;
  final String? icon, ext;
  final int added;
  bool adult;

  Item({
    required this.type,
    required this.id,
    required this.name,
    required this.cat,
    this.icon,
    this.ext,
    this.added = 0,
    this.adult = false,
  });

  factory Item.fromApi(MediaType t, Map m) {
    final isSeries = t == MediaType.series;
    return Item(
      type: t,
      id: '${isSeries ? m['series_id'] : m['stream_id']}',
      name: str(m['name']) ?? '?',
      cat: str(m['category_id']) ?? '',
      icon: str(isSeries ? m['cover'] : m['stream_icon']),
      ext: str(m['container_extension']),
      added: int.tryParse('${m['added'] ?? m['last_modified'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name': name,
        'cat': cat,
        'icon': icon,
        'ext': ext,
        'added': added,
        'adult': adult,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        type: mediaTypeFrom(j['type']),
        id: '${j['id']}',
        name: '${j['name']}',
        cat: '${j['cat']}',
        icon: str(j['icon']),
        ext: str(j['ext']),
        added: (j['added'] as num?)?.toInt() ?? 0,
        adult: j['adult'] == true,
      );
}

/// Oynatilacak tek bir oge (kanal, film veya dizi bolumu).
class PlayEntry {
  final MediaType type;
  final String id, title, cat;
  final String? icon, ext, seriesId;
  bool adult;

  PlayEntry({
    required this.type,
    required this.id,
    required this.title,
    required this.cat,
    this.icon,
    this.ext,
    this.seriesId,
    this.adult = false,
  });

  factory PlayEntry.fromItem(Item i) => PlayEntry(
        type: i.type,
        id: i.id,
        title: i.name,
        cat: i.cat,
        icon: i.icon,
        ext: i.ext,
        adult: i.adult,
      );

  String get key => '${type.name}:$id';

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'title': title,
        'cat': cat,
        'icon': icon,
        'ext': ext,
        'seriesId': seriesId,
        'adult': adult,
      };

  factory PlayEntry.fromJson(Map<String, dynamic> j) => PlayEntry(
        type: mediaTypeFrom(j['type']),
        id: '${j['id']}',
        title: '${j['title']}',
        cat: '${j['cat']}',
        icon: str(j['icon']),
        ext: str(j['ext']),
        seriesId: str(j['seriesId']),
        adult: j['adult'] == true,
      );
}

class Episode {
  final String id, title, ext;
  final int season, num;
  final String? icon;
  const Episode({
    required this.id,
    required this.title,
    required this.ext,
    required this.season,
    required this.num,
    this.icon,
  });

  PlayEntry toEntry(Item series) => PlayEntry(
        type: MediaType.series,
        id: id,
        title: '${series.name} · S$season B$num',
        cat: series.cat,
        icon: icon ?? series.icon,
        ext: ext,
        seriesId: series.id,
        adult: series.adult,
      );
}

class SeriesInfo {
  final String? plot, cover, genre, rating;
  final Map<int, List<Episode>> seasons;
  const SeriesInfo({this.plot, this.cover, this.genre, this.rating, required this.seasons});
}
